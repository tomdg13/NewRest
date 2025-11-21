

class AppConfig {

  static const String baseUrl = 'https://sabaiapp.com';
  // static const String baseUrl = 'http://localhost:3000';
  // static const String baseUrl = 'http://192.168.0.26:3000';
  
  //static const String baseUrl = 'http://209.97.172.105:3000';
  //  static const String baseUrl = 'http://10.0.28.122:3000';
  
  
  static Uri api(String endpoint) {
    return Uri.parse('$baseUrl$endpoint');
  }
  static String photoUrl(String photoName) {
    return '$baseUrl/photos/$photoName';
  }
}
