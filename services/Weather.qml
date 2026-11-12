pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Weather from Open-Meteo (no API key). Coordinates come only from settings.json →
// weather.latitude / weather.longitude (never geolocated). weather.units: "metric" | "imperial".
// The last result is cached in the state dir and refreshed every 30 min, plus on
// ensureFresh() (called by the cards when they become visible).
Singleton {
    id: root

    readonly property var lat: Config.weather?.latitude ?? null
    readonly property var lon: Config.weather?.longitude ?? null
    readonly property string units: Config.weather?.units === "imperial" ? "imperial" : "metric"
    readonly property bool configured: typeof lat === "number" && typeof lon === "number"
    readonly property int refreshMs: (Config.weather?.refreshMinutes ?? 30) * 60000

    readonly property string tempUnit: units === "imperial" ? "°F" : "°C"
    readonly property string windUnit: units === "imperial" ? "mph" : "km/h"

    property bool loading: false
    property string error: ""
    property real fetchedAt: 0
    readonly property bool hasData: current !== null

    // { temp, feelsLike, humidity, wind, windDir, code, isDay, text, icon }
    property var current: null
    // [{ date (Date), code, text, icon, max, min, precip }], [0] = today
    property var daily: []
    readonly property var today: daily.length > 0 ? daily[0] : null

    readonly property string setupHint: "Set weather.latitude / longitude in settings.json"

    function key(): string {
        return `${lat},${lon},${units}`;
    }

    function ensureFresh(): void {
        if (configured && (!hasData || Date.now() - fetchedAt > refreshMs))
            refresh();
    }

    function refresh(): void {
        if (!configured || loading)
            return;
        loading = true;
        const imperial = units === "imperial";
        const url = "https://api.open-meteo.com/v1/forecast" + `?latitude=${lat}&longitude=${lon}` + "&current=temperature_2m,apparent_temperature,relative_humidity_2m,weather_code,wind_speed_10m,wind_direction_10m,is_day" + "&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max" + "&timezone=auto&forecast_days=7" + (imperial ? "&temperature_unit=fahrenheit&wind_speed_unit=mph" : "");
        const k = key();
        const xhr = new XMLHttpRequest();
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return;
            loading = false;
            if (xhr.status !== 200) {
                error = xhr.status === 0 ? "Network error" : `HTTP ${xhr.status}`;
                console.warn("Weather: fetch failed:", error);
                return;
            }
            try {
                const data = JSON.parse(xhr.responseText);
                apply(data);
                fetchedAt = Date.now();
                error = "";
                cache.setText(JSON.stringify({
                    key: k,
                    fetchedAt: fetchedAt,
                    data: data
                }));
            } catch (e) {
                error = "Bad response";
                console.warn("Weather: parse failed:", e);
            }
        };
        xhr.open("GET", url);
        xhr.send();
    }

    function apply(d: var): void {
        const c = d.current;
        current = {
            temp: c.temperature_2m,
            feelsLike: c.apparent_temperature,
            humidity: c.relative_humidity_2m,
            wind: c.wind_speed_10m,
            windDir: c.wind_direction_10m,
            code: c.weather_code,
            isDay: c.is_day === 1,
            text: describe(c.weather_code),
            icon: icon(c.weather_code, c.is_day === 1)
        };
        const dd = d.daily;
        const out = [];
        for (let i = 0; i < (dd.time?.length ?? 0); i++) {
            const [y, m, day] = dd.time[i].split("-").map(Number);
            out.push({
                date: new Date(y, m - 1, day),
                code: dd.weather_code[i],
                text: describe(dd.weather_code[i]),
                icon: icon(dd.weather_code[i], true),
                max: dd.temperature_2m_max[i],
                min: dd.temperature_2m_min[i],
                precip: dd.precipitation_probability_max?.[i] ?? null
            });
        }
        daily = out;
    }

    // WMO weather interpretation codes
    function describe(code: int): string {
        switch (code) {
        case 0:
            return "Clear sky";
        case 1:
            return "Mainly clear";
        case 2:
            return "Partly cloudy";
        case 3:
            return "Overcast";
        case 45:
            return "Fog";
        case 48:
            return "Rime fog";
        case 51:
            return "Light drizzle";
        case 53:
            return "Drizzle";
        case 55:
            return "Dense drizzle";
        case 56:
        case 57:
            return "Freezing drizzle";
        case 61:
            return "Light rain";
        case 63:
            return "Rain";
        case 65:
            return "Heavy rain";
        case 66:
        case 67:
            return "Freezing rain";
        case 71:
            return "Light snow";
        case 73:
            return "Snow";
        case 75:
            return "Heavy snow";
        case 77:
            return "Snow grains";
        case 80:
            return "Light showers";
        case 81:
            return "Showers";
        case 82:
            return "Violent showers";
        case 85:
            return "Snow showers";
        case 86:
            return "Heavy snow showers";
        case 95:
            return "Thunderstorm";
        case 96:
        case 99:
            return "Thunderstorm, hail";
        default:
            return "Unknown";
        }
    }

    // Nerd Font (Material Design) weather glyphs
    function icon(code: int, day: bool): int {
        if (code === 0)
            return day ? 0xF0599 : 0xF0594;          // sunny / night
        if (code === 1 || code === 2)
            return day ? 0xF0595 : 0xF0F31;          // partly cloudy
        if (code === 3)
            return 0xF0590;                          // cloudy
        if (code === 45 || code === 48)
            return 0xF0591;                          // fog
        if (code >= 51 && code <= 55)
            return 0xF0F33;                          // partly rainy (drizzle)
        if (code === 56 || code === 57 || code === 66 || code === 67)
            return 0xF067F;                          // snowy-rainy
        if (code === 61 || code === 63 || code === 80 || code === 81)
            return 0xF0597;                          // rainy
        if (code === 65 || code === 82)
            return 0xF0596;                          // pouring
        if (code >= 71 && code <= 77)
            return 0xF0598;                          // snowy
        if (code === 85 || code === 86)
            return 0xF0F36;                          // heavy snow
        if (code === 95)
            return 0xF0593;                          // lightning
        if (code === 96 || code === 99)
            return 0xF067E;                          // lightning-rainy
        return 0xF0590;
    }

    function formatTemp(t: var): string {
        return t === null || t === undefined ? "—" : Math.round(t) + "°";
    }

    function windDirText(deg: real): string {
        const dirs = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"];
        return dirs[Math.round(((deg % 360) / 45)) % 8];
    }

    FileView {
        id: cache
        path: Quickshell.statePath("weather.json")
        printErrors: false
        onLoaded: {
            try {
                const c = JSON.parse(text());
                if (c.key === root.key() && c.data) {
                    root.apply(c.data);
                    root.fetchedAt = c.fetchedAt ?? 0;
                }
            } catch (e) {
                console.warn("Weather: bad cache:", e);
            }
            root.ensureFresh();
        }
        onLoadFailed: root.ensureFresh()
    }

    // Coordinates/units changed in settings.json → drop old data and refetch.
    onConfiguredChanged: keyChanged()
    onUnitsChanged: keyChanged()
    onLatChanged: keyChanged()
    onLonChanged: keyChanged()
    function keyChanged(): void {
        current = null;
        daily = [];
        fetchedAt = 0;
        error = "";
        refreshLater.restart();
    }

    // Coalesce the lat/lon/units change signals of one settings reload.
    Timer {
        id: refreshLater
        interval: 100
        onTriggered: root.ensureFresh()
    }

    Timer {
        interval: root.refreshMs
        running: root.configured
        repeat: true
        onTriggered: root.refresh()
    }
}
