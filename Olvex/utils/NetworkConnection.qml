pragma Singleton

import QtQuick
import qs.services

/**
 * NetworkConnection
 *
 * Centralized utility for network connection logic.
 */
QtObject {
    id: root

    property string previousSsid: ""

    /**
     * Handle network connection with automatic disconnection if needed.
     */
    function handleConnect(network, session, onPasswordNeeded): void {
        if (!network) return;

        // Store previous SSID before any disconnection
        if (Nmcli.active && Nmcli.active.ssid && Nmcli.active.ssid !== network.ssid) {
            root.previousSsid = Nmcli.active.ssid;
            console.log("NetworkConnection - Stored previous SSID for fallback:", root.previousSsid);
        }

        if (Nmcli.active && Nmcli.active.ssid !== network.ssid) {
            Nmcli.disconnectFromNetwork();
            Qt.callLater(() => {
                root.connectToNetwork(network, session, onPasswordNeeded);
            });
        } else {
            root.connectToNetwork(network, session, onPasswordNeeded);
        }
    }

    /**
     * Connect to a wireless network.
     */
    function connectToNetwork(network, session, onPasswordNeeded): void {
        if (!network) return;

        if (network.isSecure) {
            Nmcli.connectToNetworkWithPasswordCheck(network.ssid, network.isSecure, result => {
                if (result.needsPassword) {
                    // Clear pending connection if exists
                    if (Nmcli.pendingConnection) {
                        Nmcli.connectionCheckTimer.stop();
                        Nmcli.immediateCheckTimer.stop();
                        Nmcli.pendingConnection = null;
                    }

                    if (session && session.network) {
                        session.network.showPasswordDialog = true;
                        session.network.pendingNetwork = network;
                    } else if (onPasswordNeeded) {
                        onPasswordNeeded(network);
                    }
                } else if (!result.success) {
                    // Connection failed (e.g. wrong saved password)
                    console.log("NetworkConnection - Connection failed. Deleting broken profile and requesting password.");
                    Nmcli.checkAndDeleteConnection(network.ssid, () => {
                        if (session && session.network) {
                            session.network.showPasswordDialog = true;
                            session.network.pendingNetwork = network;
                        } else if (onPasswordNeeded) {
                            onPasswordNeeded(network);
                        }
                    });
                }
            }, network.bssid);
        } else {
            Nmcli.connectToNetwork(network.ssid, "", network.bssid, result => {
                if (result && !result.success) {
                    console.log("NetworkConnection - Unsecure connection failed. Falling back.");
                    root.forceFallback();
                }
            });
        }
    }

    /**
     * Connect with password.
     */
    function connectWithPassword(network, password, onResult): void {
        if (!network) return;
        Nmcli.connectToNetwork(network.ssid, password || "", network.bssid || "", result => {
            if (!result.success) {
                console.log("NetworkConnection - Connection with password failed. Deleting broken profile.");
                Nmcli.checkAndDeleteConnection(network.ssid, () => {
                    if (onResult) onResult(result);
                });
            } else {
                if (onResult) onResult(result);
            }
        });
    }

    /**
     * Force a fallback to the previous SSID by performing a clean disconnection first.
     */
    function forceFallback(): void {
        if (root.previousSsid === "") {
            console.log("NetworkConnection - [FORCE] Fallback aborted: No previous SSID stored.");
            return;
        }

        console.log("NetworkConnection - [FORCE] Executing hard fallback to:", root.previousSsid);
        
        // Hard reset Nmcli states
        Nmcli.disconnectFromNetwork(() => {
            Nmcli.disconnect(""); 
            Nmcli.connectionCheckTimer.stop();
            Nmcli.immediateCheckTimer.stop();
            Nmcli.pendingConnection = null;

            // Reconnect after cleanup
            const fallbackSsid = root.previousSsid;
            Nmcli.connectToNetwork(fallbackSsid, "", "", result => {
                console.log("NetworkConnection - [FORCE] Fallback result for", fallbackSsid, ":", result.success ? "SUCCESS" : "FAILED");
                if (result.success) {
                    root.previousSsid = "";
                }
            });
        });
    }
}
