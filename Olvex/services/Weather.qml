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
    property var cc
    property list<var> forecast
    property list<var> hourlyForecast

    readonly property string icon: cc ? Icons.getWeatherIcon(cc.weatherCode) : "cloud_alert"
    readonly property string description: cc?.weatherDesc ?? qsTr("No weather")
    readonly property string temp: GlobalConfig.services.useFahrenheit ? `${cc?.tempF ?? 0}°F` : `${cc?.tempC ?? 0}°C`
    readonly property string feelsLike: GlobalConfig.services.useFahrenheit ? `${cc?.feelsLikeF ?? 0}°F` : `${cc?.feelsLikeC ?? 0}°C`
    readonly property int humidity: cc?.humidity ?? 0
    readonly property real windSpeed: cc?.windSpeed ?? 0
    readonly property string sunrise: cc ? Qt.formatDateTime(new Date(cc.sunrise), GlobalConfig.services.useTwelveHourClock ? "h:mm A" : "h:mm") : "--:--"
    readonly property string sunset: cc ? Qt.formatDateTime(new Date(cc.sunset), GlobalConfig.services.useTwelveHourClock ? "h:mm A" : "h:mm") : "--:--"
    readonly property bool hasData: root.cc != null
    readonly property bool isDay: root.cc?.isDay ?? true
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
        if (c >= 51 && c <= 57)
            return 4;
        if ((c >= 61 && c <= 67) || (c >= 80 && c <= 82))
            return 5;
        if ((c >= 71 && c <= 77) || (c >= 85 && c <= 86))
            return 6;
        if (c >= 95)
            return 7;

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
        Requests.get("https://get.geojs.io/v1/ip/geo.json", text => {
            try {
                const response = JSON.parse(text);
                if (response.latitude && response.longitude) {
                    loc = response.latitude + "," + response.longitude;
                    city = response.city || response.region || "Unknown City";
                    timer.restart();
                }
            } catch (e) {
                console.log("Failed to parse geojs.io response");
            }
        });
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
        if (cachedCities.has(coords)) {
            city = cachedCities.get(coords);
            return;
        }

        const [lat, lon] = coords.split(",").map(s => s.trim());

        const fallbackToBigDataCloud = () => {
            const fallbackUrl = `https://api.bigdatacloud.net/data/reverse-geocode-client?latitude=${lat}&longitude=${lon}&localityLanguage=en`;
            Requests.get(fallbackUrl, text => {
                const geo = JSON.parse(text);
                const geoCity = geo.city || geo.locality;
                if (geoCity) {
                    city = geoCity;
                    cachedCities.set(coords, geoCity);
                } else {
                    city = "Unknown City";
                }
            });
        };

        const nominatimUrl = `https://nominatim.openstreetmap.org/reverse?lat=${lat}&lon=${lon}&format=geocodejson`;
        Requests.get(nominatimUrl, text => {
            const geo = JSON.parse(text).features?.[0]?.properties.geocoding;
            if (geo) {
                const geoCity = geo.type === "city" ? geo.name : geo.city;
                if (geoCity) {
                    city = geoCity;
                    cachedCities.set(coords, geoCity);
                    return;
                }
            }
            fallbackToBigDataCloud();
        }, fallbackToBigDataCloud);
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
        if (url === "")
            return;

        Requests.get(url, text => {
            const json = JSON.parse(text);
            if (!json.current || !json.daily)
                return;

            cc = {
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
