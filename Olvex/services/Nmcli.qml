pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property var deviceStatus: null
    property var wirelessInterfaces: []
    property var ethernetInterfaces: []
    property bool isConnected: false
    property string activeInterface: ""
    property string activeConnection: ""
    property bool wifiEnabled: true
    readonly property bool scanning: rescanProc.running
    property var networks: []
    readonly property var active: networks.find(n => n.active) ?? null
    property var savedConnections: []
    property var savedConnectionSsids: []
    property var savedProfiles: []
    property var savedProfilesBySsid: null
    property var savedProfilesByUuid: null

    property var wifiConnectionQueue: []
    property int currentSsidQueryIndex: 0
    property var pendingConnection: null
    property var wirelessDeviceDetails: null
    property var ethernetDeviceDetails: null
    property var ethernetDevices: []
    readonly property var activeEthernet: ethernetDevices.find(d => d.connected) ?? null
    property var activeProcesses: []
    property bool monitorEnabled: false

    readonly property alias connectionCheckTimer: connectionCheckTimer
    readonly property alias immediateCheckTimer: immediateCheckTimer

    // Constants
    readonly property string deviceTypeWifi: "wifi"
    readonly property string deviceTypeEthernet: "ethernet"
    readonly property string connectionTypeWireless: "802-11-wireless"
    readonly property string nmcliCommandDevice: "device"
    readonly property string nmcliCommandConnection: "connection"
    readonly property string nmcliCommandWifi: "wifi"
    readonly property string nmcliCommandRadio: "radio"
    readonly property string deviceStatusFields: "DEVICE,TYPE,STATE,CONNECTION"
    readonly property string connectionListFields: "NAME,TYPE"
    readonly property string wirelessSsidField: "802-11-wireless.ssid"
    readonly property string networkListFields: "SSID,SIGNAL,SECURITY"
    readonly property string networkDetailFields: "ACTIVE,SIGNAL,FREQ,SSID,BSSID,SECURITY"
    readonly property string securityKeyMgmt: "802-11-wireless-security.key-mgmt"
    readonly property string securityPsk: "802-11-wireless-security.psk"
    readonly property string keyMgmtWpaPsk: "wpa-psk"
    readonly property string connectionParamType: "type"
    readonly property string connectionParamConName: "con-name"
    readonly property string connectionParamIfname: "ifname"
    readonly property string connectionParamSsid: "ssid"
    readonly property string connectionParamPassword: "password"
    readonly property string connectionParamBssid: "802-11-wireless.bssid"

    signal connectionFailed(string ssid)

    function detectPasswordRequired(error: string): bool {
        if (!error || error.length === 0) {
            return false;
        }

        return (error.includes("Secrets were required") || error.includes("Secrets were required, but not provided") || error.includes("No secrets provided") || error.includes("802-11-wireless-security.psk") || error.includes("password for") || (error.includes("password") && !error.includes("Connection activated") && !error.includes("successfully")) || (error.includes("Secrets") && !error.includes("Connection activated") && !error.includes("successfully")) || (error.includes("802.11") && !error.includes("Connection activated") && !error.includes("successfully"))) && !error.includes("Connection activated") && !error.includes("successfully");
    }

    function parseNetworkOutput(output) {
        if (!output || output.length === 0) {
            return [];
        }

        const PLACEHOLDER = "STRINGWHICHHOPEFULLYWONTBEUSED";
        const rep = new RegExp("\\\\:", "g");
        const rep2 = new RegExp(PLACEHOLDER, "g");

        const allNetworks = output.trim().split("\n").filter(line => line && line.length > 0).map(n => {
            const net = n.replace(rep, PLACEHOLDER).split(":");
            return {
                active: net[0] === "yes",
                strength: parseInt(net[1] || "0", 10) || 0,
                frequency: parseInt(net[2] || "0", 10) || 0,
                ssid: (net[3] ? net[3].replace(rep2, ":") : "").trim(),
                bssid: (net[4] ? net[4].replace(rep2, ":") : "").trim(),
                security: (net[5] ? net[5] : "").trim()
            };
        }).filter(n => n.ssid && n.ssid.length > 0);

        return allNetworks;
    }

    function deduplicateNetworks(networks) {
        if (!networks || networks.length === 0) {
            return [];
        }

        const networkMap = new Map();
        for (const network of networks) {
            const existing = networkMap.get(network.ssid);
            if (!existing) {
                networkMap.set(network.ssid, network);
            } else {
                if (network.active && !existing.active) {
                    networkMap.set(network.ssid, network);
                } else if (!network.active && !existing.active) {
                    if (network.strength > existing.strength) {
                        networkMap.set(network.ssid, network);
                    }
                }
            }
        }

        return Array.from(networkMap.values());
    }

    function isConnectionCommand(command): bool {
        if (!command || command.length === 0) {
            return false;
        }

        return command.includes(root.nmcliCommandWifi) || command.includes(root.nmcliCommandConnection);
    }

    function parseDeviceStatusOutput(output, filterType) {
        if (!output || output.length === 0) {
            return [];
        }

        const interfaces = [];
        const lines = output.trim().split("\n");

        for (const line of lines) {
            const parts = line.split(":");
            if (parts.length >= 2) {
                const deviceType = parts[1];
                let shouldInclude = false;

                if (filterType === root.deviceTypeWifi && deviceType === root.deviceTypeWifi) {
                    shouldInclude = true;
                } else if (filterType === root.deviceTypeEthernet && deviceType === root.deviceTypeEthernet) {
                    shouldInclude = true;
                } else if (filterType === "both" && (deviceType === root.deviceTypeWifi || deviceType === root.deviceTypeEthernet)) {
                    shouldInclude = true;
                }

                if (shouldInclude) {
                    interfaces.push({
                        device: parts[0] || "",
                        type: parts[1] || "",
                        state: parts[2] || "",
                        connection: parts[3] || ""
                    });
                }
            }
        }

        return interfaces;
    }

    function isConnectedState(state: string): bool {
        if (!state || state.length === 0) {
            return false;
        }

        return state === "100 (connected)" || state === "connected" || state.startsWith("connected");
    }

    function executeCommand(args, callback) {
        const proc = commandProc.createObject(root);
        proc.cmdArgs = ["nmcli", ...args];
        proc.callback = callback;

        activeProcesses.push(proc);

        proc.processFinished.connect(() => {
            const index = activeProcesses.indexOf(proc);
            if (index >= 0) {
                activeProcesses.splice(index, 1);
            }
        });

        Qt.callLater(() => {
            proc.exec(proc.cmdArgs);
        });
    }

    function getDeviceStatus(callback) {
        executeCommand(["-t", "-f", root.deviceStatusFields, root.nmcliCommandDevice, "status"], result => {
            if (callback)
                callback(result.output);
        });
    }

    function getWirelessInterfaces(callback) {
        executeCommand(["-t", "-f", root.deviceStatusFields, root.nmcliCommandDevice, "status"], result => {
            const interfaces = parseDeviceStatusOutput(result.output, root.deviceTypeWifi);
            root.wirelessInterfaces = interfaces;
            if (callback)
                callback(interfaces);
        });
    }

    function getEthernetInterfaces(callback) {
        executeCommand(["-t", "-f", root.deviceStatusFields, root.nmcliCommandDevice, "status"], result => {
            const interfaces = parseDeviceStatusOutput(result.output, root.deviceTypeEthernet);
            const devices = [];

            for (const iface of interfaces) {
                const connected = isConnectedState(iface.state);

                devices.push({
                    interface: iface.device,
                    type: iface.type,
                    state: iface.state,
                    connection: iface.connection,
                    connected: connected,
                    ipAddress: "",
                    gateway: "",
                    dns: [],
                    subnet: "",
                    macAddress: "",
                    speed: ""
                });
            }

            root.ethernetInterfaces = interfaces;
            root.ethernetDevices = devices;
            if (callback)
                callback(interfaces);
        });
    }

    function connectEthernet(connectionName, interfaceName, callback) {
        if (connectionName && connectionName.length > 0) {
            executeCommand([root.nmcliCommandConnection, "up", connectionName], result => {
                if (result.success) {
                    Qt.callLater(() => {
                        getEthernetInterfaces(() => {});
                        if (interfaceName && interfaceName.length > 0) {
                            Qt.callLater(() => {
                                getEthernetDeviceDetails(interfaceName, () => {});
                            }, 1000);
                        }
                    }, 500);
                }
                if (callback)
                    callback(result);
            });
        } else if (interfaceName && interfaceName.length > 0) {
            executeCommand([root.nmcliCommandDevice, "connect", interfaceName], result => {
                if (result.success) {
                    Qt.callLater(() => {
                        getEthernetInterfaces(() => {});
                        Qt.callLater(() => {
                            getEthernetDeviceDetails(interfaceName, () => {});
                        }, 1000);
                    }, 500);
                }
                if (callback)
                    callback(result);
            });
        } else {
            if (callback)
                callback({
                    success: false,
                    output: "",
                    error: "No connection name or interface specified",
                    exitCode: -1
                });
        }
    }

    function disconnectEthernet(connectionName, callback) {
        if (!connectionName || connectionName.length === 0) {
            if (callback)
                callback({
                    success: false,
                    output: "",
                    error: "No connection name specified",
                    exitCode: -1
                });
            return;
        }

        executeCommand([root.nmcliCommandConnection, "down", connectionName], result => {
            if (result.success) {
                root.ethernetDeviceDetails = null;
                Qt.callLater(() => {
                    getEthernetInterfaces(() => {});
                }, 500);
            }
            if (callback)
                callback(result);
        });
    }

    function getAllInterfaces(callback) {
        executeCommand(["-t", "-f", root.deviceStatusFields, root.nmcliCommandDevice, "status"], result => {
            const interfaces = parseDeviceStatusOutput(result.output, "both");
            if (callback)
                callback(interfaces);
        });
    }

    function isInterfaceConnected(interfaceName, callback) {
        executeCommand([root.nmcliCommandDevice, "status"], result => {
            const lines = result.output.trim().split("\n");
            for (const line of lines) {
                const parts = line.split(/\s+/);
                if (parts.length >= 3 && parts[0] === interfaceName) {
                    const connected = isConnectedState(parts[2]);
                    if (callback)
                        callback(connected);
                    return;
                }
            }
            if (callback)
                callback(false);
        });
    }

    function connectToNetworkWithPasswordCheck(ssid, isSecure, callback, bssid) {
        if (isSecure) {
            const hasBssid = bssid !== undefined && bssid !== null && bssid.length > 0;
            connectWireless(ssid, "", bssid, result => {
                if (result.success) {
                    if (callback)
                        callback({
                            success: true,
                            usedSavedPassword: true,
                            output: result.output,
                            error: "",
                            exitCode: 0
                        });
                } else if (result.needsPassword) {
                    if (callback)
                        callback({
                            success: false,
                            needsPassword: true,
                            output: result.output,
                            error: result.error,
                            exitCode: result.exitCode
                        });
                } else {
                    if (callback)
                        callback(result);
                }
            });
        } else {
            connectWireless(ssid, "", bssid, callback);
        }
    }

    function connectToNetwork(ssid, password, bssid, callback) {
        connectWireless(ssid, password, bssid, callback);
    }

    function connectWireless(ssid, password, bssid, callback, retryCount) {
        const retries = retryCount !== undefined ? retryCount : 0;
        const maxRetries = 2;

        if (callback) {
            root.pendingConnection = {
                ssid: ssid,
                bssid: bssid || "",
                callback: callback,
                retryCount: retries
            };
            connectionCheckTimer.start();
            immediateCheckTimer.checkCount = 0;
            immediateCheckTimer.start();
        }

        let cmd = [root.nmcliCommandDevice, root.nmcliCommandWifi, "connect", ssid];
        if (password && password.length > 0) {
            cmd.push(root.connectionParamPassword, password);
        }

        executeCommand(cmd, result => {
            if (result.needsPassword && callback) {
                connectionCheckTimer.stop();
                immediateCheckTimer.stop();
                root.pendingConnection = null;
                checkAndDeleteConnection(ssid, () => {
                    loadSavedConnections(() => {});
                });
                if (callback)
                    callback(result);
                return;
            }

            if (result.success) {
                connectionCheckTimer.stop();
                immediateCheckTimer.stop();
                immediateCheckTimer.checkCount = 0;
                root.pendingConnection = null;
                loadSavedConnections(() => {});
                if (callback)
                    callback(result);
            } else if (retries < maxRetries) {
                console.warn(lc, "Connection failed, retrying... (attempt " + (retries + 1) + "/" + maxRetries + ")");
                Qt.callLater(() => {
                    connectWireless(ssid, password, bssid, callback, retries + 1);
                }, 1000);
            } else {
                connectionCheckTimer.stop();
                immediateCheckTimer.stop();
                root.pendingConnection = null;
                if (!password || password.length === 0) {
                    checkAndDeleteConnection(ssid, () => {
                        loadSavedConnections(() => {});
                    });
                }
                if (callback)
                    callback(result);
            }
        });
    }

    function createConnectionWithPassword(ssid, bssidUpper, password, callback) {
        let cmd = [root.nmcliCommandDevice, root.nmcliCommandWifi, "connect", ssid, root.connectionParamPassword, password];
        executeCommand(cmd, result => {
            if (result.success) {
                loadSavedConnections(() => {});
            }
            if (callback)
                callback(result);
        });
    }

    function checkAndDeleteConnection(ssid, callback) {
        const profile = getSavedProfile(ssid);
        if (profile && profile.uuid) {
            executeCommand([root.nmcliCommandConnection, "delete", "uuid", profile.uuid], () => {
                loadSavedConnections(() => {});
                if (callback) callback();
            });
        } else {
            executeCommand([root.nmcliCommandConnection, "delete", ssid], () => {
                loadSavedConnections(() => {});
                if (callback) callback();
            });
        }
    }

    function activateConnection(connectionName, callback) {
        executeCommand([root.nmcliCommandConnection, "up", connectionName], result => {
            if (callback)
                callback(result);
        });
    }

    function loadSavedConnections(callback) {
        executeCommand(["-t", "-f", "NAME,UUID,TYPE,AUTOCONNECT,TIMESTAMP-REAL,FILENAME", root.nmcliCommandConnection, "show"], result => {
            if (!result.success) {
                root.savedProfiles = [];
                root.savedProfilesBySsid = ({});
                root.savedProfilesByUuid = ({});
                root.savedConnections = [];
                root.savedConnectionSsids = [];
                if (callback)
                    callback([]);
                return;
            }

            parseConnectionList(result.output, callback);
        });
    }

    function parseConnectionList(output, callback) {
        const lines = output.trim().split("\n").filter(line => line.length > 0);
        const profiles = [];
        const bySsid = {};
        const byUuid = {};
        const connNames = [];
        const connSsids = [];

        for (const line of lines) {
            const parts = line.split(":");
            if (parts.length >= 3) {
                const name = parts[0];
                const uuid = parts[1];
                const type = parts[2];
                const autoconnect = parts.length > 3 ? (parts[3] === "yes" || parts[3] === "true") : true;
                const timestamp = parts.length > 4 ? parts[4] : "";
                const filename = parts.length > 5 ? parts[5] : "";
                const isWireless = (type === root.connectionTypeWireless || type === "wifi" || type === "802-11-wireless");

                const profile = {
                    name: name,
                    uuid: uuid,
                    ssid: name,
                    type: type,
                    autoconnect: autoconnect,
                    timestamp: timestamp,
                    filename: filename,
                    isWireless: isWireless
                };

                profiles.push(profile);
                connNames.push(name);
                byUuid[uuid] = profile;

                if (isWireless) {
                    const ssidLower = name.toLowerCase().trim();
                    bySsid[ssidLower] = profile;
                    if (!connSsids.includes(name)) {
                        connSsids.push(name);
                    }
                }
            }
        }

        // Atomic update to avoid UI flickering and race conditions
        root.savedProfiles = profiles;
        root.savedProfilesBySsid = bySsid;
        root.savedProfilesByUuid = byUuid;
        root.savedConnections = connNames;
        root.savedConnectionSsids = connSsids;

        if (callback) {
            callback(connSsids);
        }
    }

    function hasSavedProfile(ssid) {
        if (!ssid || ssid.length === 0) {
            return false;
        }
        const ssidLower = ssid.toLowerCase().trim();

        if (root.active && root.active.ssid) {
            const activeSsidLower = root.active.ssid.toLowerCase().trim();
            if (activeSsidLower === ssidLower) {
                return true;
            }
        }

        if (root.savedProfilesBySsid && root.savedProfilesBySsid[ssidLower] !== undefined) {
            return true;
        }

        if (root.savedConnectionSsids && root.savedConnectionSsids.some(savedSsid => savedSsid && savedSsid.toLowerCase().trim() === ssidLower)) {
            return true;
        }

        if (root.savedConnections && root.savedConnections.some(connName => connName && connName.toLowerCase().trim() === ssidLower)) {
            return true;
        }

        return false;
    }

    function isSaved(ssid) {
        return hasSavedProfile(ssid);
    }

    function getSavedProfile(ssid) {
        if (!ssid || ssid.length === 0)
            return null;
        const ssidLower = ssid.toLowerCase().trim();
        if (root.savedProfilesBySsid && root.savedProfilesBySsid[ssidLower]) {
            return root.savedProfilesBySsid[ssidLower];
        }
        return (root.savedProfiles || []).find(p => (p.ssid && p.ssid.toLowerCase().trim() === ssidLower) || (p.name && p.name.toLowerCase().trim() === ssidLower)) || null;
    }

    function forgetNetwork(ssidOrUuid, callback) {
        if (!ssidOrUuid || ssidOrUuid.length === 0) {
            if (callback)
                callback({
                    success: false,
                    output: "",
                    error: "No SSID or UUID specified",
                    exitCode: -1
                });
            return;
        }

        let targetUuid = "";
        let targetName = ssidOrUuid;

        if (root.savedProfilesByUuid && root.savedProfilesByUuid[ssidOrUuid]) {
            targetUuid = ssidOrUuid;
        } else {
            const profile = getSavedProfile(ssidOrUuid);
            if (profile && profile.uuid) {
                targetUuid = profile.uuid;
                targetName = profile.name;
            }
        }

        const cmd = targetUuid ? [root.nmcliCommandConnection, "delete", "uuid", targetUuid] : [root.nmcliCommandConnection, "delete", targetName];

        executeCommand(cmd, result => {
            if (result.success) {
                loadSavedConnections(() => {
                    rescanWifi();
                });
            }
            if (callback)
                callback(result);
        });
    }

    function forgetNetworkByUuid(uuid, callback) {
        if (!uuid) {
            if (callback)
                callback({
                    success: false,
                    output: "",
                    error: "No UUID specified",
                    exitCode: -1
                });
            return;
        }

        executeCommand([root.nmcliCommandConnection, "delete", "uuid", uuid], result => {
            if (result.success) {
                loadSavedConnections(() => {
                    rescanWifi();
                });
            }
            if (callback)
                callback(result);
        });
    }

    function setAutoconnect(uuid, enabled, callback) {
        if (!uuid) {
            if (callback) callback({ success: false, error: "No UUID specified" });
            return;
        }
        executeCommand([root.nmcliCommandConnection, "modify", uuid, "connection.autoconnect", enabled ? "yes" : "no"], result => {
            if (result.success) {
                loadSavedConnections(() => {});
            }
            if (callback) callback(result);
        });
    }

    function modifyWifiPassword(uuid, password, callback) {
        if (!uuid) {
            if (callback) callback({ success: false, error: "No UUID specified" });
            return;
        }
        executeCommand([root.nmcliCommandConnection, "modify", uuid, "802-11-wireless-security.psk", password], result => {
            if (result.success) {
                loadSavedConnections(() => {});
            }
            if (callback) callback(result);
        });
    }

    function getSavedPassword(uuid, callback) {
        if (!uuid) {
            if (callback) callback("");
            return;
        }
        executeCommand(["-s", "-g", "802-11-wireless-security.psk", root.nmcliCommandConnection, "show", uuid], result => {
            if (result.success && result.output) {
                if (callback) callback(result.output.trim());
            } else {
                if (callback) callback("");
            }
        });
    }


    function getWirelessDeviceName(): string {
        if (root.wirelessInterfaces && root.wirelessInterfaces.length > 0) {
            const activeW = root.wirelessInterfaces.find(i => isConnectedState(i.state));
            if (activeW && activeW.device) return activeW.device;
            if (root.wirelessInterfaces[0] && root.wirelessInterfaces[0].device) return root.wirelessInterfaces[0].device;
        }
        if (root.wirelessDeviceDetails && root.wirelessDeviceDetails.interface) {
            return root.wirelessDeviceDetails.interface;
        }
        return "wlan0";
    }

    function disconnect(interfaceName, callback) {
        const iface = (interfaceName && interfaceName.length > 0) ? interfaceName : getWirelessDeviceName();
        executeCommand([root.nmcliCommandDevice, "disconnect", iface], result => {
            if (result.success) {
                root.activeConnection = "";
                getNetworks(() => {});
                getWifiStatus();
            }
            if (callback)
                callback(result.success ? result.output : "");
        });
    }

    function disconnectFromNetwork(callback) {
        const iface = getWirelessDeviceName();
        executeCommand([root.nmcliCommandDevice, "disconnect", iface], result => {
            root.activeConnection = "";
            getNetworks(() => {});
            getWifiStatus();
            rescanWifi();
            if (callback) callback();
        });
    }

    function getDeviceDetails(interfaceName, callback) {
        executeCommand([root.nmcliCommandDevice, "show", interfaceName], result => {
            if (callback)
                callback(result.output);
        });
    }

    function refreshStatus(callback) {
        getDeviceStatus(output => {
            const lines = output.trim().split("\n");
            let connected = false;
            let activeIf = "";
            let activeConn = "";

            for (const line of lines) {
                const parts = line.split(":");
                if (parts.length >= 4) {
                    const state = parts[2] || "";
                    if (isConnectedState(state)) {
                        connected = true;
                        activeIf = parts[0] || "";
                        activeConn = parts[3] || "";
                        break;
                    }
                }
            }

            root.isConnected = connected;
            root.activeInterface = activeIf;
            root.activeConnection = activeConn;

            if (callback)
                callback({
                    connected,
                    interface: activeIf,
                    connection: activeConn
                });
        });
    }

    function bringInterfaceUp(interfaceName, callback) {
        if (interfaceName && interfaceName.length > 0) {
            executeCommand([root.nmcliCommandDevice, "connect", interfaceName], result => {
                if (callback) {
                    callback(result);
                }
            });
        } else {
            if (callback)
                callback({
                    success: false,
                    output: "",
                    error: "No interface specified",
                    exitCode: -1
                });
        }
    }

    function bringInterfaceDown(interfaceName, callback) {
        if (interfaceName && interfaceName.length > 0) {
            executeCommand([root.nmcliCommandDevice, "disconnect", interfaceName], result => {
                if (callback) {
                    callback(result);
                }
            });
        } else {
            if (callback)
                callback({
                    success: false,
                    output: "",
                    error: "No interface specified",
                    exitCode: -1
                });
        }
    }

    function scanWirelessNetworks(interfaceName, callback) {
        let cmd = [root.nmcliCommandDevice, root.nmcliCommandWifi, "rescan"];
        if (interfaceName && interfaceName.length > 0) {
            cmd.push(root.connectionParamIfname, interfaceName);
        }
        executeCommand(cmd, result => {
            if (callback) {
                callback(result);
            }
        });
    }

    function rescanWifi() {
        if (!rescanProc.running) {
            rescanProc.running = true;
        }
    }

    function stopWifiScan() {
        rescanProc.running = false;
    }

    function enableWifi(enabled, callback) {
        const cmd = enabled ? "on" : "off";
        executeCommand([root.nmcliCommandRadio, root.nmcliCommandWifi, cmd], result => {
            if (result.success) {
                getWifiStatus(status => {
                    root.wifiEnabled = status;
                    if (callback)
                        callback(result);
                });
            } else {
                if (callback)
                    callback(result);
            }
        });
    }

    function toggleWifi(callback) {
        const newState = !root.wifiEnabled;
        enableWifi(newState, callback);
    }

    function getWifiStatus(callback) {
        executeCommand([root.nmcliCommandRadio, root.nmcliCommandWifi], result => {
            if (result.success) {
                const enabled = result.output.trim() === "enabled";
                root.wifiEnabled = enabled;
                if (callback)
                    callback(enabled);
            } else {
                if (callback)
                    callback(root.wifiEnabled);
            }
        });
    }

    function getNetworks(callback) {
        executeCommand(["-g", root.networkDetailFields, "d", "w"], result => {
            if (!result.success) {
                if (callback)
                    callback([]);
                return;
            }

            const allNetworks = parseNetworkOutput(result.output);
            const networks = deduplicateNetworks(allNetworks);
            const rNetworks = root.networks;

            const newMap = new Map();
            for (const n of networks)
                newMap.set(`${n.frequency}:${n.ssid}:${n.bssid}`, n);

            for (let i = rNetworks.length - 1; i >= 0; i--) {
                const rn = rNetworks[i];
                const key = `${rn.frequency}:${rn.ssid}:${rn.bssid}`;
                if (!newMap.has(key)) {
                    rNetworks.splice(i, 1);
                    rn.destroy();
                }
            }

            const existingMap = new Map();
            for (const rn of rNetworks)
                existingMap.set(`${rn.frequency}:${rn.ssid}:${rn.bssid}`, rn);

            for (const [key, network] of newMap) {
                const match = existingMap.get(key);
                if (match) {
                    match.lastIpcObject = network;
                } else {
                    rNetworks.push(apComp.createObject(root, {
                        lastIpcObject: network
                    }));
                }
            }

            root.networks = [...rNetworks];

            if (callback)
                callback(root.networks);
            checkPendingConnection();
        });
    }

    function getWirelessSSIDs(interfaceName, callback) {
        let cmd = ["-t", "-f", root.networkListFields, root.nmcliCommandDevice, root.nmcliCommandWifi, "list"];
        if (interfaceName && interfaceName.length > 0) {
            cmd.push(root.connectionParamIfname, interfaceName);
        }
        executeCommand(cmd, result => {
            if (!result.success) {
                if (callback)
                    callback([]);
                return;
            }

            const ssids = [];
            const lines = result.output.trim().split("\n");
            const seenSSIDs = new Set();

            for (const line of lines) {
                if (!line || line.length === 0)
                    continue;

                const parts = line.split(":");
                if (parts.length >= 1) {
                    const ssid = parts[0].trim();
                    if (ssid && ssid.length > 0 && !seenSSIDs.has(ssid)) {
                        seenSSIDs.add(ssid);
                        const signalStr = parts.length >= 2 ? parts[1].trim() : "";
                        const signal = signalStr ? parseInt(signalStr, 10) : 0;
                        const security = parts.length >= 3 ? parts[2].trim() : "";
                        ssids.push({
                            ssid: ssid,
                            signal: signalStr,
                            signalValue: isNaN(signal) ? 0 : signal,
                            security: security
                        });
                    }
                }
            }

            ssids.sort((a, b) => {
                return b.signalValue - a.signalValue;
            });

            if (callback)
                callback(ssids);
        });
    }

    function handlePasswordRequired(proc, error: string, output: string, exitCode: int): bool {
        if (!proc || !error || error.length === 0) {
            return false;
        }

        if (!isConnectionCommand(proc.cmdArgs) || !root.pendingConnection || !root.pendingConnection.callback) {
            return false;
        }

        const needsPassword = detectPasswordRequired(error);

        if (needsPassword && !proc.callbackCalled && root.pendingConnection) {
            connectionCheckTimer.stop();
            immediateCheckTimer.stop();
            immediateCheckTimer.checkCount = 0;
            const pending = root.pendingConnection;
            root.pendingConnection = null;
            proc.callbackCalled = true;
            const result = {
                success: false,
                output: output || "",
                error: error,
                exitCode: exitCode,
                needsPassword: true
            };
            if (pending.callback) {
                pending.callback(result);
            }
            if (proc.callback && proc.callback !== pending.callback) {
                proc.callback(result);
            }
            return true;
        }

        return false;
    }

    function checkPendingConnection() {
        if (root.pendingConnection) {
            Qt.callLater(() => {
                // pendingConnection can be cleared by another path (password
                // callback, completion) between this callLater being queued and
                // it actually running — re-check here, not just at the call
                // site, or root.pendingConnection.ssid throws on null.
                const pending = root.pendingConnection;
                if (!pending)
                    return;
                const connected = root.active && root.active.ssid === pending.ssid;
                if (connected) {
                    connectionCheckTimer.stop();
                    immediateCheckTimer.stop();
                    immediateCheckTimer.checkCount = 0;
                    if (pending.callback) {
                        pending.callback({
                            success: true,
                            output: "Connected",
                            error: "",
                            exitCode: 0
                        });
                    }
                    root.pendingConnection = null;
                } else {
                    if (!immediateCheckTimer.running) {
                        immediateCheckTimer.start();
                    }
                }
            });
        }
    }

    function cidrToSubnetMask(cidr: string): string {
        const cidrNum = parseInt(cidr, 10);
        if (isNaN(cidrNum) || cidrNum < 0 || cidrNum > 32) {
            return "";
        }

        const mask = (0xffffffff << (32 - cidrNum)) >>> 0;
        const octet1 = (mask >>> 24) & 0xff;
        const octet2 = (mask >>> 16) & 0xff;
        const octet3 = (mask >>> 8) & 0xff;
        const octet4 = mask & 0xff;

        return `${octet1}.${octet2}.${octet3}.${octet4}`;
    }

    function getWirelessDeviceDetails(interfaceName, callback) {
        if (!interfaceName || interfaceName.length === 0) {
            const activeInterface = root.wirelessInterfaces.find(iface => {
                return isConnectedState(iface.state);
            });
            if (activeInterface && activeInterface.device) {
                interfaceName = activeInterface.device;
            } else {
                if (callback)
                    callback(null);
                return;
            }
        }

        executeCommand(["device", "show", interfaceName], result => {
            if (!result.success || !result.output) {
                root.wirelessDeviceDetails = null;
                if (callback)
                    callback(null);
                return;
            }

            const details = parseDeviceDetails(result.output, false);
            root.wirelessDeviceDetails = details;
            if (callback)
                callback(details);
        });
    }

    function getEthernetDeviceDetails(interfaceName, callback) {
        if (!interfaceName || interfaceName.length === 0) {
            const activeInterface = root.ethernetInterfaces.find(iface => {
                return isConnectedState(iface.state);
            });
            if (activeInterface && activeInterface.device) {
                interfaceName = activeInterface.device;
            } else {
                if (callback)
                    callback(null);
                return;
            }
        }

        executeCommand(["device", "show", interfaceName], result => {
            if (!result.success || !result.output) {
                root.ethernetDeviceDetails = null;
                if (callback)
                    callback(null);
                return;
            }

            const details = parseDeviceDetails(result.output, true);
            root.ethernetDeviceDetails = details;
            if (callback)
                callback(details);
        });
    }

    function parseDeviceDetails(output, isEthernet) {
        const details = {
            ipAddress: "",
            gateway: "",
            dns: [],
            subnet: "",
            macAddress: "",
            speed: ""
        };

        if (!output || output.length === 0) {
            return details;
        }

        const lines = output.trim().split("\n");

        for (let i = 0; i < lines.length; i++) {
            const line = lines[i];
            const parts = line.split(":");
            if (parts.length >= 2) {
                const key = parts[0].trim();
                const value = parts.slice(1).join(":").trim();

                if (key.startsWith("IP4.ADDRESS")) {
                    const ipParts = value.split("/");
                    details.ipAddress = ipParts[0] || "";
                    if (ipParts[1]) {
                        details.subnet = cidrToSubnetMask(ipParts[1]);
                    } else {
                        details.subnet = "";
                    }
                } else if (key === "IP4.GATEWAY") {
                    if (value !== "--") {
                        details.gateway = value;
                    }
                } else if (key.startsWith("IP4.DNS")) {
                    if (value !== "--" && value.length > 0) {
                        details.dns.push(value);
                    }
                } else if (isEthernet && key === "WIRED-PROPERTIES.MAC") {
                    details.macAddress = value;
                } else if (isEthernet && key === "WIRED-PROPERTIES.SPEED") {
                    details.speed = value;
                } else if (!isEthernet && key === "GENERAL.HWADDR") {
                    details.macAddress = value;
                }
            }
        }

        return details;
    }

    function refreshOnConnectionChange() {
        getNetworks(networks => {
            const newActive = root.active;

            if (newActive && newActive.active) {
                Qt.callLater(() => {
                    if (root.wirelessInterfaces.length > 0) {
                        const activeWireless = root.wirelessInterfaces.find(iface => {
                            return isConnectedState(iface.state);
                        });
                        if (activeWireless && activeWireless.device) {
                            getWirelessDeviceDetails(activeWireless.device, () => {});
                        }
                    }

                    if (root.ethernetInterfaces.length > 0) {
                        const activeEthernet = root.ethernetInterfaces.find(iface => {
                            return isConnectedState(iface.state);
                        });
                        if (activeEthernet && activeEthernet.device) {
                            getEthernetDeviceDetails(activeEthernet.device, () => {});
                        }
                    }
                }, 500);
            } else {
                root.wirelessDeviceDetails = null;
                root.ethernetDeviceDetails = null;
            }

            getWirelessInterfaces(() => {});
            getEthernetInterfaces(() => {
                if (root.activeEthernet && root.activeEthernet.connected) {
                    Qt.callLater(() => {
                        getEthernetDeviceDetails(root.activeEthernet.interface, () => {});
                    }, 500);
                }
            });
        });
    }

    function setMonitorEnabled(enabled) {
        if (root.monitorEnabled === enabled)
            return;

        root.monitorEnabled = enabled;
        monitorRestartTimer.stop();

        if (enabled) {
            if (!monitorProc.running)
                monitorProc.running = true;
        } else if (monitorProc.running) {
            monitorProc.running = false;
        }
    }

    Component.onCompleted: {
        getWifiStatus(() => {});
        getNetworks(() => {});
        loadSavedConnections(() => {});
        getEthernetInterfaces(() => {});
        setMonitorEnabled(true);

        Qt.callLater(() => {
            if (root.wirelessInterfaces.length > 0) {
                const activeWireless = root.wirelessInterfaces.find(iface => {
                    return isConnectedState(iface.state);
                });
                if (activeWireless && activeWireless.device) {
                    getWirelessDeviceDetails(activeWireless.device, () => {});
                }
            }

            if (root.ethernetInterfaces.length > 0) {
                const activeEthernet = root.ethernetInterfaces.find(iface => {
                    return isConnectedState(iface.state);
                });
                if (activeEthernet && activeEthernet.device) {
                    getEthernetDeviceDetails(activeEthernet.device, () => {});
                }
            }
        }, 2000);
    }

    Component {
        id: commandProc

        CommandProcess {}
    }

    Component {
        id: apComp

        AccessPoint {}
    }

    Timer {
        id: connectionCheckTimer

        interval: 4000
        onTriggered: {
            if (root.pendingConnection) {
                const connected = root.active && root.active.ssid === root.pendingConnection.ssid;

                if (!connected && root.pendingConnection.callback) {
                    let foundPasswordError = false;
                    for (let i = 0; i < root.activeProcesses.length; i++) {
                        const proc = root.activeProcesses[i];
                        if (proc && proc.stderr && proc.stderr.text) {
                            const error = proc.stderr.text.trim();
                            if (error && error.length > 0) {
                                if (root.isConnectionCommand(proc.cmdArgs)) {
                                    const needsPassword = root.detectPasswordRequired(error);

                                    if (needsPassword && !proc.callbackCalled && root.pendingConnection) {
                                        const pending = root.pendingConnection;
                                        root.pendingConnection = null;
                                        immediateCheckTimer.stop();
                                        immediateCheckTimer.checkCount = 0;
                                        proc.callbackCalled = true;
                                        const result = {
                                            success: false,
                                            output: (proc.stdout && proc.stdout.text) ? proc.stdout.text : "",
                                            error: error,
                                            exitCode: -1,
                                            needsPassword: true
                                        };
                                        if (pending.callback) {
                                            pending.callback(result);
                                        }
                                        if (proc.callback && proc.callback !== pending.callback) {
                                            proc.callback(result);
                                        }
                                        foundPasswordError = true;
                                        break;
                                    }
                                }
                            }
                        }
                    }

                    if (!foundPasswordError) {
                        const pending = root.pendingConnection;
                        const failedSsid = pending.ssid;
                        root.pendingConnection = null;
                        immediateCheckTimer.stop();
                        immediateCheckTimer.checkCount = 0;
                        root.connectionFailed(failedSsid);
                        pending.callback({
                            success: false,
                            output: "",
                            error: "Connection timeout",
                            exitCode: -1,
                            needsPassword: false
                        });
                    }
                } else if (connected) {
                    root.pendingConnection = null;
                    immediateCheckTimer.stop();
                    immediateCheckTimer.checkCount = 0;
                }
            }
        }
    }

    Timer {
        id: immediateCheckTimer

        property int checkCount: 0

        interval: 500
        repeat: true
        triggeredOnStart: false

        onTriggered: {
            if (root.pendingConnection) {
                checkCount++;
                const connected = root.active && root.active.ssid === root.pendingConnection.ssid;

                if (connected) {
                    connectionCheckTimer.stop();
                    immediateCheckTimer.stop();
                    immediateCheckTimer.checkCount = 0;
                    if (root.pendingConnection.callback) {
                        root.pendingConnection.callback({
                            success: true,
                            output: "Connected",
                            error: "",
                            exitCode: 0
                        });
                    }
                    root.pendingConnection = null;
                } else {
                    for (let i = 0; i < root.activeProcesses.length; i++) {
                        const proc = root.activeProcesses[i];
                        if (proc && proc.stderr && proc.stderr.text) {
                            const error = proc.stderr.text.trim();
                            if (error && error.length > 0) {
                                if (root.isConnectionCommand(proc.cmdArgs)) {
                                    const needsPassword = root.detectPasswordRequired(error);

                                    if (needsPassword && !proc.callbackCalled && root.pendingConnection && root.pendingConnection.callback) {
                                        connectionCheckTimer.stop();
                                        immediateCheckTimer.stop();
                                        immediateCheckTimer.checkCount = 0;
                                        const pending = root.pendingConnection;
                                        root.pendingConnection = null;
                                        proc.callbackCalled = true;
                                        const result = {
                                            success: false,
                                            output: (proc.stdout && proc.stdout.text) ? proc.stdout.text : "",
                                            error: error,
                                            exitCode: -1,
                                            needsPassword: true
                                        };
                                        if (pending.callback) {
                                            pending.callback(result);
                                        }
                                        if (proc.callback && proc.callback !== pending.callback) {
                                            proc.callback(result);
                                        }
                                        return;
                                    }
                                }
                            }
                        }
                    }

                    if (checkCount >= 6) {
                        immediateCheckTimer.stop();
                        immediateCheckTimer.checkCount = 0;
                    }
                }
            } else {
                immediateCheckTimer.stop();
                immediateCheckTimer.checkCount = 0;
            }
        }
    }

    Process {
        id: rescanProc

        command: ["nmcli", "dev", root.nmcliCommandWifi, "list", "--rescan", "yes"]
        onExited: root.getNetworks() // qmllint disable signal-handler-parameters
    }

    Process {
        id: monitorProc

        running: root.monitorEnabled
        command: ["nmcli", "monitor"]
        environment: ({
                LANG: "C.UTF-8",
                LC_ALL: "C.UTF-8"
            })
        stdout: SplitParser {
            onRead: root.refreshOnConnectionChange()
        }
        onExited: {
            if (root.monitorEnabled)
                monitorRestartTimer.start();
        } // qmllint disable signal-handler-parameters
    }

    Timer {
        id: monitorRestartTimer

        interval: 2000
        onTriggered: {
            monitorProc.running = true;
        }
    }

    LoggingCategory {
        id: lc

        name: "olvex.qml.services.nmcli"
        defaultLogLevel: LoggingCategory.Info
    }

    component CommandProcess: Process {
        id: proc

        property var callback: null
        property var cmdArgs: []
        property bool callbackCalled: false
        property int exitCode: 0

        signal processFinished

        environment: ({
                LANG: "C.UTF-8",
                LC_ALL: "C.UTF-8"
            })

        stdout: StdioCollector {
            id: stdoutCollector
        }

        stderr: StdioCollector {
            id: stderrCollector

            onStreamFinished: {
                const error = text.trim();
                if (error && error.length > 0) {
                    const output = (stdoutCollector && stdoutCollector.text) ? stdoutCollector.text : "";
                    root.handlePasswordRequired(proc, error, output, -1);
                }
            }
        }

        onExited: code => { // qmllint disable signal-handler-parameters
            exitCode = code;

            Qt.callLater(() => {
                if (callbackCalled) {
                    processFinished();
                    return;
                }

                if (proc.callback) {
                    const output = (stdoutCollector && stdoutCollector.text) ? stdoutCollector.text : "";
                    const error = (stderrCollector && stderrCollector.text) ? stderrCollector.text : "";
                    const success = exitCode === 0;
                    const cmdIsConnection = isConnectionCommand(proc.cmdArgs);

                    if (root.handlePasswordRequired(proc, error, output, exitCode)) {
                        processFinished();
                        return;
                    }

                    const needsPassword = cmdIsConnection && root.detectPasswordRequired(error);

                    if (!success && cmdIsConnection && root.pendingConnection) {
                        const failedSsid = root.pendingConnection.ssid;
                        root.connectionFailed(failedSsid);
                    }

                    callbackCalled = true;
                    callback({
                        success: success,
                        output: output,
                        error: error,
                        exitCode: proc.exitCode,
                        needsPassword: needsPassword || false
                    });
                    processFinished();
                } else {
                    processFinished();
                }
            });
        }
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
