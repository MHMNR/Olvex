pragma Singleton

import QtQuick
import Quickshell
import qs.services

Singleton {
    id: root

    property var networks: []
    readonly property var active: (networks && networks.find) ? (networks.find(n => n.active) || null) : null
    property bool wifiEnabled: true
    readonly property bool scanning: Nmcli.scanning
    property var ethernetDevices: []
    readonly property var activeEthernet: (ethernetDevices && ethernetDevices.find) ? (ethernetDevices.find(d => d.connected) || null) : null
    property int ethernetDeviceCount: 0
    property bool ethernetProcessRunning: false
    property var ethernetDeviceDetails: null
    property var wirelessDeviceDetails: null
    property var pendingConnection: null
    property var savedConnections: []
    property var savedConnectionSsids: []
    property var savedProfiles: []

    signal connectionFailed(string ssid)

    function enableWifi(enabled: bool) {
        Nmcli.enableWifi(enabled, result => {
            if (result.success) {
                root.getWifiStatus();
                Nmcli.getNetworks(() => {
                    syncNetworksFromNmcli();
                });
            }
        });
    }

    function toggleWifi() {
        Nmcli.toggleWifi(result => {
            if (result.success) {
                root.getWifiStatus();
                Nmcli.getNetworks(() => {
                    syncNetworksFromNmcli();
                });
            }
        });
    }

    function rescanWifi() {
        Nmcli.rescanWifi();
    }

    function connectToNetwork(ssid: string, password: string, bssid: string, callback) {
        // Set up pending connection tracking if callback provided
        if (callback) {
            const hasBssid = bssid !== undefined && bssid !== null && bssid.length > 0;
            root.pendingConnection = {
                ssid: ssid,
                bssid: hasBssid ? bssid : "",
                callback: callback
            };
        }

        Nmcli.connectToNetwork(ssid, password, bssid, result => {
            if (result && result.success) {
                // Connection successful
                if (callback)
                    callback(result);
                root.pendingConnection = null;
            } else if (result && result.needsPassword) {
                // Password needed - callback will handle showing dialog
                if (callback)
                    callback(result);
            } else {
                // Connection failed
                if (result && result.error) {
                    root.connectionFailed(ssid);
                }
                if (callback)
                    callback(result);
                root.pendingConnection = null;
            }
        });
    }

    function connectToNetworkWithPasswordCheck(ssid: string, isSecure: bool, callback, bssid: string) {
        // Set up pending connection tracking
        const hasBssid = bssid !== undefined && bssid !== null && bssid.length > 0;
        root.pendingConnection = {
            ssid: ssid,
            bssid: hasBssid ? bssid : "",
            callback: callback
        };

        Nmcli.connectToNetworkWithPasswordCheck(ssid, isSecure, result => {
            if (result && result.success) {
                // Connection successful
                if (callback)
                    callback(result);
                root.pendingConnection = null;
            } else if (result && result.needsPassword) {
                // Password needed - callback will handle showing dialog
                if (callback)
                    callback(result);
            } else {
                // Connection failed
                if (result && result.error) {
                    root.connectionFailed(ssid);
                }
                if (callback)
                    callback(result);
                root.pendingConnection = null;
            }
        }, bssid);
    }

    function disconnectFromNetwork() {
        // Try to disconnect - use connection name if available, otherwise use device
        Nmcli.disconnectFromNetwork();
        // Refresh network list after disconnection
        Qt.callLater(() => {
            Nmcli.getNetworks(() => {
                syncNetworksFromNmcli();
            });
        }, 500);
    }

    function forgetNetwork(ssid: string) {
        // Delete the connection profile for this network
        // This will remove the saved password and connection settings
        Nmcli.forgetNetwork(ssid, result => {
            if (result.success) {
                // Refresh network list after deletion
                Qt.callLater(() => {
                    Nmcli.getNetworks(() => {
                        syncNetworksFromNmcli();
                    });
                }, 500);
            }
        });
    }

    function syncNetworksFromNmcli() {
        const rNetworks = root.networks;
        const nNetworks = Nmcli.networks;

        // Build a map of existing networks by key
        const existingMap = new Map();
        for (const rn of rNetworks) {
            const key = `${rn.frequency}:${rn.ssid}:${rn.bssid}`;
            existingMap.set(key, rn);
        }

        // Build a map of new networks by key
        const newMap = new Map();
        for (const nn of nNetworks) {
            const key = `${nn.frequency}:${nn.ssid}:${nn.bssid}`;
            newMap.set(key, nn);
        }

        // Remove networks that no longer exist
        for (const [key, network] of existingMap) {
            if (!newMap.has(key)) {
                const index = rNetworks.indexOf(network);
                if (index >= 0) {
                    rNetworks.splice(index, 1);
                    network.destroy();
                }
            }
        }

        // Add or update networks from Nmcli
        for (const [key, nNetwork] of newMap) {
            const existing = existingMap.get(key);
            if (existing) {
                // Update existing network's lastIpcObject
                existing.lastIpcObject = nNetwork.lastIpcObject;
            } else {
                // Create new AccessPoint from Nmcli's data
                rNetworks.push(apComp.createObject(root, {
                    lastIpcObject: nNetwork.lastIpcObject
                }));
            }
        }
    }

    function hasSavedProfile(ssid: string): bool {
        return Nmcli.hasSavedProfile(ssid);
    }

    function getSavedProfile(ssid: string) {
        return Nmcli.getSavedProfile(ssid);
    }

    function forgetNetworkWithCallback(ssidOrUuid: string, callback) {
        Nmcli.forgetNetwork(ssidOrUuid, callback);
    }

    function forgetNetworkByUuid(uuid: string, callback) {
        Nmcli.forgetNetworkByUuid(uuid, callback);
    }

    function getWifiStatus() {
        Nmcli.getWifiStatus(enabled => {
            root.wifiEnabled = enabled;
        });
    }

    function getEthernetDevices() {
        root.ethernetProcessRunning = true;
        Nmcli.getEthernetInterfaces(interfaces => {
            root.ethernetDevices = Nmcli.ethernetDevices;
            root.ethernetDeviceCount = Nmcli.ethernetDevices.length;
            root.ethernetProcessRunning = false;
        });
    }

    function connectEthernet(connectionName: string, interfaceName: string) {
        Nmcli.connectEthernet(connectionName, interfaceName, result => {
            if (result.success) {
                getEthernetDevices();
                // Refresh device details after connection
                Qt.callLater(() => {
                    const activeDevice = root.ethernetDevices.find(function (d) {
                        return d.connected;
                    });
                    if (activeDevice && activeDevice.interface) {
                        updateEthernetDeviceDetails(activeDevice.interface);
                    }
                }, 1000);
            }
        });
    }

    function disconnectEthernet(connectionName: string) {
        Nmcli.disconnectEthernet(connectionName, result => {
            if (result.success) {
                getEthernetDevices();
                // Clear device details after disconnection
                Qt.callLater(() => {
                    root.ethernetDeviceDetails = null;
                });
            }
        });
    }

    function updateEthernetDeviceDetails(interfaceName: string) {
        Nmcli.getEthernetDeviceDetails(interfaceName, details => {
            root.ethernetDeviceDetails = details;
        });
    }

    function updateWirelessDeviceDetails() {
        // Find the wireless interface by looking for wifi devices
        // Pass empty string to let Nmcli find the active interface automatically
        Nmcli.getWirelessDeviceDetails("", details => {
            root.wirelessDeviceDetails = details;
        });
    }

    function cidrToSubnetMask(cidr: string): string {
        // Convert CIDR notation (e.g., "24") to subnet mask (e.g., "255.255.255.0")
        const cidrNum = parseInt(cidr);
        if (isNaN(cidrNum) || cidrNum < 0 || cidrNum > 32) {
            return "";
        }

        const mask = (0xffffffff << (32 - cidrNum)) >>> 0;
        const octets = [(mask >>> 24) & 0xff, (mask >>> 16) & 0xff, (mask >>> 8) & 0xff, mask & 0xff];

        return octets.join(".");
    }

    Component.onCompleted: {
        // Trigger ethernet device detection after initialization
        Qt.callLater(() => {
            getEthernetDevices();
        });
        // Load saved connections on startup
        Nmcli.loadSavedConnections(() => {
            root.savedConnections = Nmcli.savedConnections;
            root.savedConnectionSsids = Nmcli.savedConnectionSsids;
        });
        // Get initial WiFi status
        Nmcli.getWifiStatus(enabled => {
            root.wifiEnabled = enabled;
        });
        // Sync networks from Nmcli on startup
        Qt.callLater(() => {
            syncNetworksFromNmcli();
        }, 100);
    }

    Connections {
        target: Nmcli
        function onNetworksChanged() {
            syncNetworksFromNmcli();
        }
        function onEthernetDevicesChanged() {
            root.ethernetDevices = Nmcli.ethernetDevices;
            root.ethernetDeviceCount = Nmcli.ethernetDevices.length;
        }
    }

    // Sync saved connections from Nmcli when they're updated
    Connections {
        target: Nmcli

        function onSavedConnectionsChanged() {
            root.savedConnections = Nmcli.savedConnections;
        }

        function onSavedConnectionSsidsChanged() {
            root.savedConnectionSsids = Nmcli.savedConnectionSsids;
        }

        function onSavedProfilesChanged() {
            root.savedProfiles = Nmcli.savedProfiles;
        }
    }

    Component {
        id: apComp

        AccessPoint {}
    }

    component AccessPoint: QtObject {
        required property var lastIpcObject
        readonly property string ssid: lastIpcObject.ssid
        readonly property string bssid: lastIpcObject.bssid
        readonly property int strength: lastIpcObject.strength
        readonly property int frequency: lastIpcObject.frequency
        readonly property bool active: lastIpcObject.active
        readonly property string security: lastIpcObject.security
        readonly property bool isSecure: security.length > 0
    }
}
