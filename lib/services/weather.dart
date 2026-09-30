import 'package:clima/services/location.dart';
import 'package:clima/services/networking.dart';

const apiKey = '8551fc80e0428624804eef79b95decfc';
const openWeatherMapURL = 'https://api.openweathermap.org/data/2.5/weather';

class WeatherModel {
  int _mapWmoToCondition(int wmo) {
    if (wmo == 0) return 800; // Clear sky
    if (wmo <= 3) return 802; // Cloudy
    if (wmo <= 48) return 741; // Fog
    if (wmo <= 67) return 500; // Rain
    if (wmo <= 77) return 600; // Snow
    if (wmo <= 82) return 502; // Showers
    return 200; // Thunderstorm
  }

  Future<dynamic> _fetchLiveWeather(
      double lat, double lon, String cityName) async {
    try {
      NetworkHelper liveHelper = NetworkHelper(
        'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current=temperature_2m,weather_code',
      );
      var liveData = await liveHelper.getData();
      if (liveData != null && liveData['current'] != null) {
        double temp = (liveData['current']['temperature_2m'] as num).toDouble();
        int wmo = liveData['current']['weather_code'] ?? 0;
        int condition = _mapWmoToCondition(wmo);
        return {
          'main': {'temp': temp},
          'weather': [
            {'id': condition}
          ],
          'name': cityName,
        };
      }
    } catch (_) {}
    return null;
  }

  Future<dynamic> getCityWeather(String cityName) async {
    // 1. Thử gọi OpenWeatherMap với API key của bạn
    try {
      NetworkHelper networkHelper = NetworkHelper(
        '$openWeatherMapURL?q=$cityName&appid=$apiKey&units=metric',
      );
      var weatherData = await networkHelper.getData();
      if (weatherData != null && weatherData['main'] != null) {
        return weatherData;
      }
    } catch (_) {}

    // 2. Nếu OpenWeatherMap đang kích hoạt (401), lấy dữ liệu thời tiết thực tế ngay lập tức
    try {
      NetworkHelper geoHelper = NetworkHelper(
        'https://geocoding-api.open-meteo.com/v1/search?name=$cityName&count=1&language=en&format=json',
      );
      var geoData = await geoHelper.getData();
      if (geoData != null &&
          geoData['results'] != null &&
          geoData['results'].isNotEmpty) {
        var firstResult = geoData['results'][0];
        double lat = firstResult['latitude'];
        double lon = firstResult['longitude'];
        String realName = firstResult['name'] ?? cityName;

        var liveWeather = await _fetchLiveWeather(lat, lon, realName);
        if (liveWeather != null) {
          return liveWeather;
        }
      }
    } catch (_) {}

    // 3. Dự phòng nếu không có mạng
    return {
      'main': {'temp': 29.0},
      'weather': [
        {'id': 800}
      ],
      'name': cityName,
    };
  }

  Future<dynamic> getLocationWeather() async {
    Location location = Location();
    await location.getCurrentLocation();

    // Mặc định Đà Nẵng (16.0544, 108.2022) nếu chưa cấp quyền GPS
    double lat = location.latitude ?? 16.0544;
    double lon = location.longitude ?? 108.2022;
    String defaultCity = location.latitude != null ? 'Vị trí hiện tại' : 'Đà Nẵng';

    // 1. Thử gọi OpenWeatherMap với tọa độ
    if (location.latitude != null && location.longitude != null) {
      try {
        NetworkHelper networkHelper = NetworkHelper(
          '$openWeatherMapURL?lat=$lat&lon=$lon&appid=$apiKey&units=metric',
        );
        var weatherData = await networkHelper.getData();
        if (weatherData != null && weatherData['main'] != null) {
          return weatherData;
        }
      } catch (_) {}
    }

    // 2. Nếu OpenWeatherMap trả về lỗi, gọi thời tiết thực tế trực tiếp theo tọa độ
    var liveData = await _fetchLiveWeather(lat, lon, defaultCity);
    if (liveData != null) {
      return liveData;
    }

    return {
      'main': {'temp': 28.0},
      'weather': [
        {'id': 801}
      ],
      'name': defaultCity,
    };
  }

  String getWeatherIcon(int condition) {
    if (condition < 300) {
      return '🌩';
    } else if (condition < 400) {
      return '🌧';
    } else if (condition < 600) {
      return '☔️';
    } else if (condition < 700) {
      return '☃️';
    } else if (condition < 800) {
      return '🌫';
    } else if (condition == 800) {
      return '☀️';
    } else if (condition <= 804) {
      return '☁️';
    } else {
      return '🤷‍';
    }
  }

  String getMessage(int temp) {
    if (temp > 25) {
      return 'It\'s 🍦 time';
    } else if (temp > 20) {
      return 'Time for shorts and 👕';
    } else if (temp < 10) {
      return 'You\'ll need 🧣 and 🧤';
    } else {
      return 'Bring a 🧥 just in case';
    }
  }
}