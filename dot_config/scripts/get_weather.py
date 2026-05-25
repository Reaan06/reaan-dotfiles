import requests
import json
import os
import subprocess
from datetime import datetime, timedelta

# Persistent storage for weather telemetry
CACHE_PATH = os.path.expanduser("~/.cache/weather.json")

def get_location():
    """Attempt to get precise location using multiple strategies."""
    # Strategy 1: Multi-provider IP Geolocation fallback
    providers = [
        'https://ipapi.co/json/',
        'http://ip-api.com/json/',
        'https://freegeoip.app/json/'
    ]
    
    for url in providers:
        try:
            resp = requests.get(url, timeout=3).json()
            if 'latitude' in resp:
                return resp['city'], resp['latitude'], resp['longitude']
            elif 'lat' in resp:
                return resp['city'], resp['lat'], resp['lon']
        except:
            continue
    
    return "Desconocido", 19.4326, -99.1332 # Default to CDMX

def get_weather():
    try:
        city, lat, lon = get_location()

        # Load historical cache
        archive = {"city": city, "days": {}}
        if os.path.exists(CACHE_PATH):
            try:
                with open(CACHE_PATH, 'r') as f:
                    archive = json.load(f)
            except:
                pass

        # Fetch APIs (Forecast + Archive)
        # Open-Meteo is free and doesn't require a key
        forecast_url = f"https://api.open-meteo.com/v1/forecast?latitude={lat}&longitude={lon}&hourly=temperature_2m,relative_humidity_2m,precipitation_probability,weather_code,wind_speed_10m&timezone=auto&forecast_days=8"
        f_resp = requests.get(forecast_url, timeout=7).json()

        past_start = (datetime.now() - timedelta(days=7)).strftime('%Y-%m-%d')
        past_end = (datetime.now() - timedelta(days=1)).strftime('%Y-%m-%d')
        hist_url = f"https://archive-api.open-meteo.com/v1/archive?latitude={lat}&longitude={lon}&start_date={past_start}&end_date={past_end}&hourly=temperature_2m,relative_humidity_2m,weather_code,wind_speed_10m&timezone=auto"
        h_resp = requests.get(hist_url, timeout=7).json()

        def ingest(api_data):
            if 'hourly' not in api_data: return
            h = api_data['hourly']
            for i, t_str in enumerate(h['time']):
                dt = datetime.fromisoformat(t_str)
                d_key = dt.strftime('%Y-%m-%d')
                h_key = dt.strftime('%H:00')
                if d_key not in archive['days']: archive['days'][d_key] = []
                
                # Upsert hour
                entry = {
                    "hour": h_key,
                    "temp": h['temperature_2m'][i],
                    "humidity": h.get('relative_humidity_2m', [0]*len(h['time']))[i],
                    "rain": h.get('precipitation_probability', [0]*len(h['time']))[i],
                    "wind": h['wind_speed_10m'][i],
                    "code": h['weather_code'][i]
                }
                
                # Check if entry exists to update or append
                found = False
                for existing in archive['days'][d_key]:
                    if existing['hour'] == h_key:
                        existing.update(entry)
                        found = True
                        break
                if not found:
                    archive['days'][d_key].append(entry)
            
            # Sort days
            for d in archive['days']:
                archive['days'][d].sort(key=lambda x: x['hour'])

        ingest(h_resp)
        ingest(f_resp)

        # Cleanup old data (keep only 14 days)
        cutoff = datetime.now() - timedelta(days=14)
        archive['days'] = {k: v for k, v in archive['days'].items() if datetime.strptime(k, '%Y-%m-%d') > cutoff}

        archive.update({
            "city": city,
            "lat": lat,
            "lon": lon,
            "current_time": datetime.now().strftime("%H:%M"),
            "current_date": datetime.now().strftime("%Y-%m-%d")
        })

        output = json.dumps(archive)
        os.makedirs(os.path.dirname(CACHE_PATH), exist_ok=True)
        with open(CACHE_PATH, 'w') as f: f.write(output)
        print(output)

    except Exception as e:
        if os.path.exists(CACHE_PATH):
            with open(CACHE_PATH, 'r') as f: print(f.read())
        else:
            print(json.dumps({"error": str(e), "city": "Error", "days": {}}))

if __name__ == "__main__":
    get_weather()

if __name__ == "__main__":
    get_weather()
