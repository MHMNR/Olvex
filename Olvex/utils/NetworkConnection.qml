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
    function handleConnect(network, session, onPasswordNeeded) {
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
    function connectToNetwork(network, session, onPasswordNeeded) {
        if (!network) return;

        if (network.isSecure) {
            Nmcli.connectToNetworkWithPasswordCheck(network.ssid, network.isSecure, result => {
                if (result.needsPassword) {
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
                    const errMsg = (result.error || "").toLowerCase();
                    const isAuthError = errMsg.includes("secret") || errMsg.includes("password") || errMsg.includes("agent") || errMsg.includes("key-mgmt");

                    console.warn("NetworkConnection - Connection failed:", result.error || "Unknown error");
                    if (isAuthError) {
                        if (session && session.network) {
                            session.network.showPasswordDialog = true;
                            session.network.pendingNetwork = network;
                        } else if (onPasswordNeeded) {
                            onPasswordNeeded(network);
                        }
                    }
                }
            }, network.bssid);
        } else {
            Nmcli.connectToNetwork(network.ssid, "", network.bssid, result => {
                if (result && !result.success) {
                    console.warn("NetworkConnection - Unsecure connection failed. Falling back.");
                    root.forceFallback();
                }
            });
        }
    }

    /**
     * Connect with password.
     */
    function connectWithPassword(network, password, onResult) {
        if (!network) return;
        Nmcli.connectToNetwork(network.ssid, password || "", network.bssid || "", result => {
            if (onResult)
                onResult(result);
        });
    }

    /**
     * Force a fallback to the previous SSID by performing a clean disconnection first.
     */
    function forceFallback() {
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
