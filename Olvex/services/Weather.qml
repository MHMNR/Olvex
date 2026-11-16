pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Olvex
import Olvex.Config
import qs.utils

Singleton {
    id: root

    property string city
    property string loc
    property var realCc: null
    property bool demoMode: false
    property int demoIndex: 0
    readonly property var demoPresets: [
        { weatherCode: 0, weatherDesc: "Clear", tempC: 29, tempF: 84, feelsLikeC: 31, feelsLikeF: 88, humidity: 48, windSpeed: 10, isDay: 1, demoCycle: 0.45, sunrise: "2026-11-16 06:15", sunset: "2026-11-16 17:10" },
        { weatherCode: 2, weatherDesc: "Partly cloudy", tempC: 26, tempF: 79, feelsLikeC: 28, feelsLikeF: 82, humidity: 58, windSpeed: 16, isDay: 1, demoCycle: 0.35, sunrise: "2026-11-16 06:15", sunset: "2026-11-16 17:10" },
        { weatherCode: 3, weatherDesc: "Overcast", tempC: 23, tempF: 73, feelsLikeC: 24, feelsLikeF: 75, humidity: 72, windSpeed: 20, isDay: 1, demoCycle: 0.50, sunrise: "2026-11-16 06:15", sunset: "2026-11-16 17:10" },
        { weatherCode: 45, weatherDesc: "Fog", tempC: 18, tempF: 64, feelsLikeC: 18, feelsLikeF: 64, humidity: 94, windSpeed: 5, isDay: 1, demoCycle: 0.12, sunrise: "2026-11-16 06:15", sunset: "2026-11-16 17:10" },
        { weatherCode: 53, weatherDesc: "Drizzle", tempC: 22, tempF: 72, feelsLikeC: 23, feelsLikeF: 73, humidity: 86, windSpeed: 14, isDay: 1, demoCycle: 0.40, sunrise: "2026-11-16 06:15", sunset: "2026-11-16 17:10" },
        { weatherCode: 66, weatherDesc: "Sleet", tempC: 1, tempF: 34, feelsLikeC: -3, feelsLikeF: 27, humidity: 90, windSpeed: 28, isDay: 1, demoCycle: 0.45, sunrise: "2026-11-16 06:15", sunset: "2026-11-16 17:10" },
        { weatherCode: 63, weatherDesc: "Rain", tempC: 21, tempF: 70, feelsLikeC: 21, feelsLikeF: 70, humidity: 92, windSpeed: 24, isDay: 1, demoCycle: 0.50, sunrise: "2026-11-16 06:15", sunset: "2026-11-16 17:10" },
        { weatherCode: 65, weatherDesc: "Heavy rain", tempC: 19, tempF: 66, feelsLikeC: 18, feelsLikeF: 64, humidity: 97, windSpeed: 42, isDay: 1, demoCycle: 0.55, sunrise: "2026-11-16 06:15", sunset: "2026-11-16 17:10" },
        { weatherCode: 73, weatherDesc: "Snow", tempC: -3, tempF: 27, feelsLikeC: -7, feelsLikeF: 19, humidity: 85, windSpeed: 22, isDay: 1, demoCycle: 0.50, sunrise: "2026-11-16 06:15", sunset: "2026-11-16 17:10" },
        { weatherCode: 95, weatherDesc: "Thunderstorm", tempC: 24, tempF: 75, feelsLikeC: 26, feelsLikeF: 79, humidity: 95, windSpeed: 48, isDay: 0, demoCycle: 1.50, sunrise: "2026-11-16 06:15", sunset: "2026-11-16 17:10" },
        { weatherCode: 96, weatherDesc: "Storm + Hail", tempC: 16, tempF: 61, feelsLikeC: 14, feelsLikeF: 57, humidity: 94, windSpeed: 54, isDay: 0, demoCycle: 1.50, sunrise: "2026-11-16 06:15", sunset: "2026-11-16 17:10" },
        { weatherCode: 0, weatherDesc: "Clear night", tempC: 20, tempF: 68, feelsLikeC: 20, feelsLikeF: 68, humidity: 65, windSpeed: 8, isDay: 0, demoCycle: 1.50, sunrise: "2026-11-16 06:15", sunset: "2026-11-16 17:10" },
        { weatherCode: 2, weatherDesc: "Cloudy night", tempC: 19, tempF: 66, feelsLikeC: 19, feelsLikeF: 66, humidity: 74, windSpeed: 14, isDay: 0, demoCycle: 1.55, sunrise: "2026-11-16 06:15", sunset: "2026-11-16 17:10" },
        { weatherCode: 999, weatherDesc: "Haze & Heat", demoIcon: "wb_twilight", tempC: 39, tempF: 102, feelsLikeC: 44, feelsLikeF: 111, humidity: 42, windSpeed: 18, isDay: 1, demoCycle: 0.65, sunrise: "2026-11-16 06:15", sunset: "2026-11-16 17:10" }
    ]
    readonly property var cc: demoMode ? demoPresets[demoIndex % demoPresets.length] : realCc
    property list<var> forecast
    property list<var> hourlyForecast
    property bool loading: false

    readonly property string icon: cc ? (cc.demoIcon ?? Icons.getWeatherIcon(cc.weatherCode)) : "cloud_alert"
    readonly property string description: cc?.weatherDesc ?? qsTr("No weather")
    readonly property string temp: GlobalConfig.services.useFahrenheit ? `${cc?.tempF ?? 0}°F` : `${cc?.tempC ?? 0}°C`
    readonly property string feelsLike: GlobalConfig.services.useFahrenheit ? `${cc?.feelsLikeF ?? 0}°F` : `${cc?.feelsLikeC ?? 0}°C`
    readonly property int humidity: cc?.humidity ?? 0
    readonly property real windSpeed: cc?.windSpeed ?? 0
    readonly property string sunrise: cc ? Qt.formatDateTime(new Date(cc.sunrise), GlobalConfig.services.useTwelveHourClock ? "h:mm A" : "h:mm") : "--:--"
    readonly property string sunset: cc ? Qt.formatDateTime(new Date(cc.sunset), GlobalConfig.services.useTwelveHourClock ? "h:mm A" : "h:mm") : "--:--"
    property real nowMs: Date.now()

    property real demoTimeMs: {
        const d = new Date();
        d.setHours(6, 0, 0, 0);
        return d.getTime();
    }
    readonly property real activeTimeMs: demoMode ? demoTimeMs : nowMs

    Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: root.nowMs = Date.now()
    }

    onCcChanged: root.nowMs = Date.now()

    Timer {
        interval: 4500
        running: root.demoMode
        repeat: true
        onTriggered: root.demoIndex = (root.demoIndex + 1) % root.demoPresets.length
    }

    Timer {
        interval: 100
        running: root.demoMode
        repeat: true
        onTriggered: {
            const start = new Date();
            start.setHours(6, 0, 0, 0);
            const base = start.getTime();
            const stepMs = (2 * 86400000) / ((root.demoPresets.length * 4500) / interval);
            const next = root.demoTimeMs + stepMs;
            root.demoTimeMs = (next >= base + 86400000) ? (next - 86400000) : next;
        }
    }

    readonly property bool hasData: root.cc != null
    readonly property bool isDay: {
        if (cc && cc.sunrise && cc.sunset) {
            const sr = new Date(cc.sunrise).getTime();
            const ss = new Date(cc.sunset).getTime();
            if (!isNaN(sr) && !isNaN(ss) && ss > sr)
                return root.activeTimeMs >= sr && root.activeTimeMs <= ss;
        }
        return root.cc?.isDay ?? true;
    }
    function dayCycleForTime(ms: real): real {
        if (!cc || !cc.sunrise || !cc.sunset)
            return isDay ? 0.38 : 1.50;
        const sr = new Date(cc.sunrise).getTime();
        const ss = new Date(cc.sunset).getTime();
        if (isNaN(sr) || isNaN(ss) || ss <= sr)
            return isDay ? 0.38 : 1.50;
        const dayLen = ss - sr;
        const nightLen = Math.max(1, 86400000 - dayLen);
        let t = ms;
        while (t < sr)
            t += 86400000;
        while (t >= sr + 86400000)
            t -= 86400000;
        if (t <= ss)
            return (t - sr) / dayLen;
        return 1.0 + (t - ss) / nightLen;
    }

    readonly property real dayCycle: dayCycleForTime(root.activeTimeMs)
    readonly property real sunProgress: (dayCycle <= 1.0) ? dayCycle : -1.0
    readonly property real moonPhase: {
        const synodicMs = 2551442861.0; // 29.53058867 days
        const epochMs = 947182440000.0; // 2000-01-06 18:14 UTC New Moon
        const diff = root.activeTimeMs - epochMs;
        return (((diff % synodicMs) + synodicMs) % synodicMs) / synodicMs;
    }
    readonly property real visualKind: root.visualKindFromCode(root.cc?.weatherCode, root.isDay)

    function visualKindFromCode(code, isDay: bool): real {
        if (code === undefined || code === null)
            return 10;

        const c = parseInt(code);
        if (isNaN(c))
            return 10;

        if (c <= 1)
            return isDay ? 0 : 8;
        if (c === 2)
            return isDay ? 1 : 9;
        if (c === 3)
            return 2;
        if (c === 45 || c === 48)
            return 3;
        if (c >= 51 && c <= 55)
            return 4;
        if (c === 56 || c === 57 || c === 66 || c === 67)
            return 11;
        if (c === 65 || c === 82)
            return 12;
        if ((c >= 61 && c <= 64) || (c >= 80 && c <= 81))
            return 5;
        if ((c >= 71 && c <= 77) || (c >= 85 && c <= 86))
            return 6;
        if (c === 95)
            return 7;
        if (c >= 96 && c <= 99)
            return 13;
        if (c === 999)
            return 14;

        return 2;
    }
    readonly property string windLabel: root.cc ? `${Math.round(root.windSpeed)} km/h` : "--"
    readonly property var todayForecast: root.forecast?.length > 0 ? root.forecast[0] : null
    readonly property string todayHighLow: {
        const day = root.todayForecast;
        if (!day)
            return "--";
        if (GlobalConfig.services.useFahrenheit)
            return `${day.minTempF}° / ${day.maxTempF}°`;
        return `${day.minTempC}° / ${day.maxTempC}°`;
    }

    readonly property var weekRange: {
        const days = root.forecast ?? [];
        if (days.length === 0)
            return { min: 0, max: 1, span: 1 };

        const useF = GlobalConfig.services.useFahrenheit;
        let min = Number.POSITIVE_INFINITY;
        let max = Number.NEGATIVE_INFINITY;

        for (let i = 0; i < days.length; i++) {
            const day = days[i];
            const lo = useF ? day.minTempF : day.minTempC;
            const hi = useF ? day.maxTempF : day.maxTempC;
            min = Math.min(min, lo);
            max = Math.max(max, hi);
        }

        return {
            min: min,
            max: max,
            span: Math.max(1, max - min)
        };
    }

    function formatHourLabel(hour24: int): string {
        if (GlobalConfig.services.useTwelveHourClock) {
            const am = hour24 < 12;
            const h12 = hour24 % 12 || 12;
            return `${h12}${am ? "a" : "p"}`;
        }
        return `${hour24}`;
    }

    function formatTempValue(celsius: real, fahrenheit: real): string {
        return GlobalConfig.services.useFahrenheit ? `${fahrenheit}°` : `${celsius}°`;
    }

    readonly property var cachedCities: new Map()

    function fetchCoordsFromIp(): void {
        const tryGeojs = () => {
            Requests.get("https://get.geojs.io/v1/ip/geo.json", text => {
                try {
                    const response = JSON.parse(text);
                    if (response.latitude && response.longitude) {
                        loc = response.latitude + "," + response.longitude;
                        if (response.city || response.region) {
                            city = response.city || response.region;
                            cachedCities.set(loc, city);
                        } else {
                            fetchCityFromCoords(loc);
                        }
                        timer.restart();
                    }
                } catch (e) {
                    console.log("Failed to parse geojs.io response");
                }
            });
        };

        Requests.get("https://ipwho.is/", text => {
            try {
                const response = JSON.parse(text);
                if (response.success && response.latitude && response.longitude) {
                    loc = response.latitude + "," + response.longitude;
                    if (response.city && response.city.length > 0) {
                        city = response.city;
                        cachedCities.set(loc, response.city);
                    } else if (response.region && response.region.length > 0) {
                        city = response.region;
                        cachedCities.set(loc, response.region);
                    } else {
                        fetchCityFromCoords(loc);
                    }
                    timer.restart();
                    return;
                }
            } catch (e) {
                console.log("Failed to parse ipwho.is response");
            }
            tryGeojs();
        }, tryGeojs);
    }

    function forceReload(): void {
        loading = true;
        const configLocation = GlobalConfig.services.weatherLocation;
        if (configLocation) {
            if (configLocation.indexOf(",") !== -1 && !isNaN(parseFloat(configLocation.split(",")[0]))) {
                if (loc === configLocation)
                    fetchWeatherData();
                else
                    loc = configLocation;
                fetchCityFromCoords(configLocation);
            } else {
                fetchCoordsFromCity(configLocation);
            }
        } else if (loc && loc.indexOf(",") !== -1) {
            fetchWeatherData();
        } else if (CUtils.fileExists("/usr/lib/geoclue-2.0/demos/where-am-i")) {
            geoclueProcess.running = true;
        } else {
            fetchCoordsFromIp();
        }
    }

    function reload(): void {
        const configLocation = GlobalConfig.services.weatherLocation;

        if (configLocation) {
            if (configLocation.indexOf(",") !== -1 && !isNaN(parseFloat(configLocation.split(",")[0]))) {
                loc = configLocation;
                fetchCityFromCoords(configLocation);
            } else {
                fetchCoordsFromCity(configLocation);
            }
        } else if (!loc || timer.elapsed() > 900) {
            if (CUtils.fileExists("/usr/lib/geoclue-2.0/demos/where-am-i")) {
                geoclueProcess.running = true;
            } else {
                fetchCoordsFromIp();
            }
        }
    }

    function fetchCityFromCoords(coords: string): void {
        if (!coords || coords.indexOf(",") === -1)
            return;

        if (cachedCities.has(coords)) {
            city = cachedCities.get(coords);
            return;
        }

        const [lat, lon] = coords.split(",").map(s => s.trim());

        const fallbackToNominatim = () => {
            const nominatimUrl = `https://nominatim.openstreetmap.org/reverse?lat=${lat}&lon=${lon}&format=json&accept-language=en`;
            Requests.get(nominatimUrl, text => {
                try {
                    const geo = JSON.parse(text);
                    const addr = geo.address;
                    const geoCity = addr ? (addr.city || addr.town || addr.municipality || addr.village || addr.suburb || addr.county || addr.state) : (geo.name || geo.display_name);
                    if (geoCity && geoCity.length > 0) {
                        city = geoCity;
                        cachedCities.set(coords, geoCity);
                    }
                } catch (e) {
                    console.log("Failed to parse nominatim response");
                }
            }, () => {}, { "User-Agent": "OlvexShell/1.0" });
        };

        const bdcUrl = `https://api.bigdatacloud.net/data/reverse-geocode-client?latitude=${lat}&longitude=${lon}&localityLanguage=en`;
        Requests.get(bdcUrl, text => {
            try {
                const geo = JSON.parse(text);
                const geoCity = geo.city || geo.locality || geo.principalSubdivision;
                if (geoCity && geoCity.length > 0) {
                    city = geoCity;
                    cachedCities.set(coords, geoCity);
                } else {
                    fallbackToNominatim();
                }
            } catch (e) {
                fallbackToNominatim();
            }
        }, fallbackToNominatim);
    }

    function fetchCoordsFromCity(cityName: string): void {
        const url = `https://geocoding-api.open-meteo.com/v1/search?name=${encodeURIComponent(cityName)}&count=1&language=en&format=json`;

        Requests.get(url, text => {
            const json = JSON.parse(text);
            if (json.results && json.results.length > 0) {
                const result = json.results[0];
                loc = result.latitude + "," + result.longitude;
                city = result.name;
            } else {
                loc = "";
                reload();
            }
        });
    }

    function fetchWeatherData(): void {
        const url = getWeatherUrl();
        if (url === "") {
            loading = false;
            return;
        }

        loading = true;
        Requests.get(url, text => {
            try {
                const json = JSON.parse(text);
                if (!json.current || !json.daily)
                    return;

                realCc = {
                    weatherCode: json.current.weather_code,
                    weatherDesc: getWeatherCondition(json.current.weather_code),
                    tempC: Math.round(json.current.temperature_2m),
                    tempF: Math.round(toFahrenheit(json.current.temperature_2m)),
                    feelsLikeC: Math.round(json.current.apparent_temperature),
                    feelsLikeF: Math.round(toFahrenheit(json.current.apparent_temperature)),
                    humidity: json.current.relative_humidity_2m,
                    windSpeed: json.current.wind_speed_10m,
                    isDay: json.current.is_day,
                    sunrise: json.daily.sunrise[0].replace("T", " "),
                    sunset: json.daily.sunset[0].replace("T", " ")
                };

                const forecastList = [];
                for (let i = 0; i < json.daily.time.length; i++)
                    forecastList.push({
                        date: json.daily.time[i].replace(/-/g, "/"),
                        maxTempC: Math.round(json.daily.temperature_2m_max[i]),
                        maxTempF: Math.round(toFahrenheit(json.daily.temperature_2m_max[i])),
                        minTempC: Math.round(json.daily.temperature_2m_min[i]),
                        minTempF: Math.round(toFahrenheit(json.daily.temperature_2m_min[i])),
                        weatherCode: json.daily.weather_code[i],
                        icon: Icons.getWeatherIcon(json.daily.weather_code[i])
                    });
                forecast = forecastList;

                const hourlyList = [];
                const now = new Date();
                for (let i = 0; i < json.hourly.time.length; i++) {
                    const time = new Date(json.hourly.time[i].replace("T", " "));

                    if (time < now)
                        continue;

                    hourlyList.push({
                        timestamp: json.hourly.time[i],
                        hour: time.getHours(),
                        tempC: Math.round(json.hourly.temperature_2m[i]),
                        tempF: Math.round(toFahrenheit(json.hourly.temperature_2m[i])),
                        weatherCode: json.hourly.weather_code[i],
                        icon: Icons.getWeatherIcon(json.hourly.weather_code[i])
                    });
                }
                hourlyForecast = hourlyList;
                timer.restart();
            } finally {
                loading = false;
            }
        }, () => {
            loading = false;
        });
    }

    function toFahrenheit(celcius: real): real {
        return celcius * 9 / 5 + 32;
    }

    function getWeatherUrl(): string {
        if (!loc || loc.indexOf(",") === -1)
            return "";

        const [lat, lon] = loc.split(",").map(s => s.trim());
        const baseUrl = "https://api.open-meteo.com/v1/forecast";
        const params = ["latitude=" + lat, "longitude=" + lon, "hourly=weather_code,temperature_2m", "daily=weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset", "current=temperature_2m,relative_humidity_2m,apparent_temperature,is_day,weather_code,wind_speed_10m", "timezone=auto", "forecast_days=7"];

        return baseUrl + "?" + params.join("&");
    }

    function getWeatherCondition(code: string): string {
        const conditions = {
            "0": "Clear",
            "1": "Clear",
            "2": "Partly cloudy",
            "3": "Overcast",
            "45": "Fog",
            "48": "Fog",
            "51": "Drizzle",
            "53": "Drizzle",
            "55": "Drizzle",
            "56": "Freezing drizzle",
            "57": "Freezing drizzle",
            "61": "Light rain",
            "63": "Rain",
            "65": "Heavy rain",
            "66": "Light rain",
            "67": "Heavy rain",
            "71": "Light snow",
            "73": "Snow",
            "75": "Heavy snow",
            "77": "Snow",
            "80": "Light rain",
            "81": "Rain",
            "82": "Heavy rain",
            "85": "Light snow showers",
            "86": "Heavy snow showers",
            "95": "Thunderstorm",
            "96": "Thunderstorm with hail",
            "99": "Thunderstorm with hail"
        };
        return conditions[code] || "Unknown";
    }

    onLocChanged: fetchWeatherData()

    Connections {
        function onWeatherLocationChanged(): void {
            root.reload();
        }

        target: GlobalConfig.services
    }

    Timer {
        interval: 3600000 // 1 hour
        running: true
        repeat: true
        onTriggered: fetchWeatherData()
    }

    ElapsedTimer {
        id: timer
    }

    function toggleDemoMode(): void {
        if (!root.demoMode) {
            const d = new Date();
            d.setHours(6, 0, 0, 0);
            root.demoTimeMs = d.getTime();
            root.demoIndex = 0;
            root.demoMode = true;
        } else {
            root.demoMode = false;
        }
    }

    IpcHandler {
        function toggleDemo(): void {
            root.toggleDemoMode();
        }

        function nextDemo(): void {
            root.demoMode = true;
            root.demoIndex = (root.demoIndex + 1) % root.demoPresets.length;
        }

        function setDemo(index: int): void {
            root.demoMode = true;
            root.demoIndex = Math.max(0, Math.min(root.demoPresets.length - 1, index));
        }

        target: "weather"
    }

    Process {
        id: geoclueProcess
        command: ["/usr/lib/geoclue-2.0/demos/where-am-i", "-t", "5"]
        stdout: StdioCollector {
            onStreamFinished: {
                let parsedLat = "";
                let parsedLon = "";
                let accuracy = 999999;
                
                const lines = text.split("\n");
                for (let i = 0; i < lines.length; i++) {
                    if (lines[i].trim().startsWith("Latitude:")) {
                        parsedLat = lines[i].split(":")[1].trim().replace("°", "");
                    } else if (lines[i].trim().startsWith("Longitude:")) {
                        parsedLon = lines[i].split(":")[1].trim().replace("°", "");
                    } else if (lines[i].trim().startsWith("Accuracy:")) {
                        accuracy = parseFloat(lines[i].split(":")[1].trim().replace(" meters", ""));
                    }
                }
                
                // Only trust Geoclue if it has high accuracy (less than 10km)
                // Desktop Wi-Fi/IP fallbacks in Geoclue often give 25000m+ which is highly inaccurate
                if (parsedLat !== "" && parsedLon !== "" && accuracy < 10000) {
                    loc = parsedLat + "," + parsedLon;
                    root.fetchCityFromCoords(loc);
                    timer.restart();
                } else {
                    root.fetchCoordsFromIp();
                }
            }
        }
    }
}
