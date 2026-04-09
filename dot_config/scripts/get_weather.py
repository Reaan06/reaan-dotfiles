import requests
import json
import sys
from datetime import datetime, timedelta

def get_weather():
    try:
        # 1. Get location via IP
        loc = requests.get('https://ipapi.co/json/').json()
        lat, lon = loc['latitude'], loc['longitude']
        city = loc['city']

        # 2. Get 30 days forecast (Open-Meteo)
        # We fetch hourly data for the next 35 days to be safe
        end_date = (datetime.now() + timedelta(days=34)).strftime('%Y-%m-%d')
        url = f"https://api.open-meteo.com/v1/forecast?latitude={lat}&longitude={lon}&hourly=temperature_2m,relative_humidity_2m,precipitation_probability,weather_code,wind_speed_10m&timezone=auto&forecast_days=35"
        
        data = requests.get(url).json()
        
        weather_data = {
            "city": city,
            "current_time": datetime.now().strftime("%H:%M"),
            "days": {}
        }

        hourly = data['hourly']
        for i, time_str in enumerate(hourly['time']):
            dt = datetime.fromisoformat(time_str)
            date_key = dt.strftime('%Y-%m-%d')
            hour_key = dt.strftime('%H:00')

            if date_key not in weather_data['days']:
                weather_data['days'][date_key] = []

            weather_data['days'][date_key].append({
                "hour": hour_key,
                "temp": hourly['temperature_2m'][i],
                "humidity": hourly['relative_humidity_2m'][i],
                "rain": hourly['precipitation_probability'][i],
                "wind": hourly['wind_speed_10m'][i],
                "code": hourly['weather_code'][i]
            })

        print(json.dumps(weather_data))
    except Exception as e:
        print(json.dumps({"error": str(e)}))

if __name__ == "__main__":
    get_weather()
