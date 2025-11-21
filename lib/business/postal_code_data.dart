// postal_code_data.dart

class PostalCode {
  final String code;
  final String province;
  final String district;

  const PostalCode({
    required this.code,
    required this.province,
    required this.district,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PostalCode && other.code == code;
  }

  @override
  int get hashCode => code.hashCode;

  @override
  String toString() => '$code - $district, $province';
}

class PostalCodeData {
  static List<PostalCode> getAllPostalCodes() {
    return [
      // Vientiane Capital (Prefecture) - 01XXX
      PostalCode(code: '01000', province: 'Vientiane Capital', district: 'Chanthabuly'),
      PostalCode(code: '01010', province: 'Vientiane Capital', district: 'Sikhottabong'),
      PostalCode(code: '01020', province: 'Vientiane Capital', district: 'Xaysetha'),
      PostalCode(code: '01120', province: 'Vientiane Capital', district: 'Hadxaifong'),
      PostalCode(code: '01160', province: 'Vientiane Capital', district: 'Sangthong'),
      PostalCode(code: '01180', province: 'Vientiane Capital', district: 'Naxaithong'),
      PostalCode(code: '01190', province: 'Vientiane Capital', district: 'Xaythany'),
      PostalCode(code: '01200', province: 'Vientiane Capital', district: 'Sisattanak'),
      PostalCode(code: '01210', province: 'Vientiane Capital', district: 'Parkngum'),

      // Phongsaly Province - 02XXX
      PostalCode(code: '02000', province: 'Phongsaly', district: 'Phongsaly'),
      PostalCode(code: '02010', province: 'Phongsaly', district: 'May'),
      PostalCode(code: '02020', province: 'Phongsaly', district: 'Khua'),
      PostalCode(code: '02030', province: 'Phongsaly', district: 'Samphanh'),
      PostalCode(code: '02040', province: 'Phongsaly', district: 'Bountai'),
      PostalCode(code: '02050', province: 'Phongsaly', district: 'Bounneua'),
      PostalCode(code: '02060', province: 'Phongsaly', district: 'Nhot Ou'),

      // Luang Namtha Province - 03XXX
      PostalCode(code: '03000', province: 'Luang Namtha', district: 'Luang Namtha'),
      PostalCode(code: '03010', province: 'Luang Namtha', district: 'Sing'),
      PostalCode(code: '03020', province: 'Luang Namtha', district: 'Long'),
      PostalCode(code: '03030', province: 'Luang Namtha', district: 'Viengphoukha'),
      PostalCode(code: '03040', province: 'Luang Namtha', district: 'Nalae'),

      // Oudomxay Province - 04XXX
      PostalCode(code: '04000', province: 'Oudomxay', district: 'Oudomxay'),
      PostalCode(code: '04010', province: 'Oudomxay', district: 'Xay'),
      PostalCode(code: '04020', province: 'Oudomxay', district: 'La'),
      PostalCode(code: '04030', province: 'Oudomxay', district: 'Beng'),
      PostalCode(code: '04040', province: 'Oudomxay', district: 'Houn'),
      PostalCode(code: '04050', province: 'Oudomxay', district: 'Pak Beng'),
      PostalCode(code: '04060', province: 'Oudomxay', district: 'Namor'),

      // Bokeo Province - 05XXX
      PostalCode(code: '05000', province: 'Bokeo', district: 'Houayxay'),
      PostalCode(code: '05010', province: 'Bokeo', district: 'Tonpheung'),
      PostalCode(code: '05020', province: 'Bokeo', district: 'Meung'),
      PostalCode(code: '05030', province: 'Bokeo', district: 'Pha Oudom'),
      PostalCode(code: '05040', province: 'Bokeo', district: 'Paktha'),

      // Luang Prabang Province - 06XXX
      PostalCode(code: '06000', province: 'Luang Prabang', district: 'Luang Prabang'),
      PostalCode(code: '06010', province: 'Luang Prabang', district: 'Nan'),
      PostalCode(code: '06020', province: 'Luang Prabang', district: 'Pak Ou'),
      PostalCode(code: '06030', province: 'Luang Prabang', district: 'Nambak'),
      PostalCode(code: '06040', province: 'Luang Prabang', district: 'Ngoi'),
      PostalCode(code: '06050', province: 'Luang Prabang', district: 'Pak Xeng'),
      PostalCode(code: '06060', province: 'Luang Prabang', district: 'Phonxay'),
      PostalCode(code: '06070', province: 'Luang Prabang', district: 'Chomphet'),
      PostalCode(code: '06080', province: 'Luang Prabang', district: 'Viengkhan'),
      PostalCode(code: '06090', province: 'Luang Prabang', district: 'Phou Khoun'),
      PostalCode(code: '06100', province: 'Luang Prabang', district: 'Xiengnguen'),
      PostalCode(code: '06110', province: 'Luang Prabang', district: 'Vangvieng'),

      // Houaphanh Province - 07XXX
      PostalCode(code: '07000', province: 'Houaphanh', district: 'Xam Neua'),
      PostalCode(code: '07010', province: 'Houaphanh', district: 'Xamtai'),
      PostalCode(code: '07020', province: 'Houaphanh', district: 'Viangthong'),
      PostalCode(code: '07030', province: 'Houaphanh', district: 'Viengxay'),
      PostalCode(code: '07040', province: 'Houaphanh', district: 'Houameung'),
      PostalCode(code: '07050', province: 'Houaphanh', district: 'Aed'),
      PostalCode(code: '07060', province: 'Houaphanh', district: 'Kouan'),
      PostalCode(code: '07070', province: 'Houaphanh', district: 'Sopbao'),
      PostalCode(code: '07080', province: 'Houaphanh', district: 'Xiengkor'),

      // Xayaboury Province - 08XXX
      PostalCode(code: '08000', province: 'Xayabouly', district: 'Xayabouly'),
      PostalCode(code: '08010', province: 'Xayabouly', district: 'Hongsa'),
      PostalCode(code: '08020', province: 'Xayabouly', district: 'Ngeun'),
      PostalCode(code: '08030', province: 'Xayabouly', district: 'Xienghon'),
      PostalCode(code: '08040', province: 'Xayabouly', district: 'Phiang'),
      PostalCode(code: '08050', province: 'Xayabouly', district: 'Parklai'),
      PostalCode(code: '08060', province: 'Xayabouly', district: 'Kenethao'),
      PostalCode(code: '08070', province: 'Xayabouly', district: 'Botene'),
      PostalCode(code: '08080', province: 'Xayabouly', district: 'Thongmyxay'),
      PostalCode(code: '08090', province: 'Xayabouly', district: 'Paklay'),
      PostalCode(code: '08100', province: 'Xayabouly', district: 'Sainyabuli'),

      // Xiengkhouang Province - 09XXX
      PostalCode(code: '09000', province: 'Xiengkhouang', district: 'Phonsavan'),
      PostalCode(code: '09010', province: 'Xiengkhouang', district: 'Pek'),
      PostalCode(code: '09020', province: 'Xiengkhouang', district: 'Kham'),
      PostalCode(code: '09030', province: 'Xiengkhouang', district: 'Nonghet'),
      PostalCode(code: '09040', province: 'Xiengkhouang', district: 'Khoun'),
      PostalCode(code: '09050', province: 'Xiengkhouang', district: 'Morkmay'),
      PostalCode(code: '09060', province: 'Xiengkhouang', district: 'Paek'),
      PostalCode(code: '09070', province: 'Xiengkhouang', district: 'Thathom'),

      // Vientiane Province - 10XXX
      PostalCode(code: '10000', province: 'Vientiane', district: 'Vangvieng'),
      PostalCode(code: '10010', province: 'Vientiane', district: 'Phonhong'),
      PostalCode(code: '10020', province: 'Vientiane', district: 'Thoulakhom'),
      PostalCode(code: '10030', province: 'Vientiane', district: 'Keo Oudom'),
      PostalCode(code: '10040', province: 'Vientiane', district: 'Kasi'),
      PostalCode(code: '10050', province: 'Vientiane', district: 'Feuang'),
      PostalCode(code: '10060', province: 'Vientiane', district: 'Xanakharm'),
      PostalCode(code: '10070', province: 'Vientiane', district: 'Mad'),
      PostalCode(code: '10080', province: 'Vientiane', district: 'Viengkham'),
      PostalCode(code: '10090', province: 'Vientiane', district: 'Hinheub'),
      PostalCode(code: '10100', province: 'Vientiane', district: 'Met'),

      // Borikhamxay Province - 11XXX
      PostalCode(code: '11000', province: 'Borikhamxay', district: 'Pakxan'),
      PostalCode(code: '11010', province: 'Borikhamxay', district: 'Thaphabath'),
      PostalCode(code: '11020', province: 'Borikhamxay', district: 'Pakkading'),
      PostalCode(code: '11030', province: 'Borikhamxay', district: 'Borikhan'),
      PostalCode(code: '11040', province: 'Borikhamxay', district: 'Khamkeuth'),
      PostalCode(code: '11050', province: 'Borikhamxay', district: 'Viengthong'),

      // Khammouan Province - 12XXX
      PostalCode(code: '12000', province: 'Khammouan', district: 'Thakhek'),
      PostalCode(code: '12010', province: 'Khammouan', district: 'Mahaxay'),
      PostalCode(code: '12020', province: 'Khammouan', district: 'Hinboun'),
      PostalCode(code: '12030', province: 'Khammouan', district: 'Nongbok'),
      PostalCode(code: '12040', province: 'Khammouan', district: 'Yommalath'),
      PostalCode(code: '12050', province: 'Khammouan', district: 'Gnommalath'),
      PostalCode(code: '12060', province: 'Khammouan', district: 'Boualapha'),
      PostalCode(code: '12070', province: 'Khammouan', district: 'Nakai'),
      PostalCode(code: '12080', province: 'Khammouan', district: 'Xebangfay'),

      // Savannakhet Province - 13XXX
      PostalCode(code: '13000', province: 'Savannakhet', district: 'Kaysone Phomvihane'),
      PostalCode(code: '13010', province: 'Savannakhet', district: 'Champhone'),
      PostalCode(code: '13020', province: 'Savannakhet', district: 'Songkhone'),
      PostalCode(code: '13030', province: 'Savannakhet', district: 'Xayboury'),
      PostalCode(code: '13040', province: 'Savannakhet', district: 'Outhoumphone'),
      PostalCode(code: '13050', province: 'Savannakhet', district: 'Thapangthong'),
      PostalCode(code: '13060', province: 'Savannakhet', district: 'Nong'),
      PostalCode(code: '13070', province: 'Savannakhet', district: 'Xonbuly'),
      PostalCode(code: '13080', province: 'Savannakhet', district: 'Phin'),
      PostalCode(code: '13090', province: 'Savannakhet', district: 'Sepon'),
      PostalCode(code: '13100', province: 'Savannakhet', district: 'Vilabuly'),
      PostalCode(code: '13110', province: 'Savannakhet', district: 'Xaibouly'),
      PostalCode(code: '13120', province: 'Savannakhet', district: 'Atsaphangthong'),
      PostalCode(code: '13130', province: 'Savannakhet', district: 'Phalanxay'),
      PostalCode(code: '13140', province: 'Savannakhet', district: 'Kaisonbounvihan'),
      PostalCode(code: '13150', province: 'Savannakhet', district: 'Atsaphone'),

      // Salavan Province - 14XXX
      PostalCode(code: '14000', province: 'Salavan', district: 'Salavan'),
      PostalCode(code: '14010', province: 'Salavan', district: 'Toumlane'),
      PostalCode(code: '14020', province: 'Salavan', district: 'Lao Ngam'),
      PostalCode(code: '14030', province: 'Salavan', district: 'Taoye'),
      PostalCode(code: '14040', province: 'Salavan', district: 'Khongxedone'),
      PostalCode(code: '14050', province: 'Salavan', district: 'Lakhonpheng'),
      PostalCode(code: '14060', province: 'Salavan', district: 'Samuoy'),
      PostalCode(code: '14070', province: 'Salavan', district: 'Va Py'),

      // Sekong Province - 15XXX
      PostalCode(code: '15000', province: 'Sekong', district: 'Lamam'),
      PostalCode(code: '15010', province: 'Sekong', district: 'Kaleum'),
      PostalCode(code: '15020', province: 'Sekong', district: 'Dakchung'),
      PostalCode(code: '15030', province: 'Sekong', district: 'Thateng'),

      // Champasak Province - 16XXX
      PostalCode(code: '16000', province: 'Champasak', district: 'Pakse'),
      PostalCode(code: '16010', province: 'Champasak', district: 'Bachiangchaleunsook'),
      PostalCode(code: '16020', province: 'Champasak', district: 'Champasak'),
      PostalCode(code: '16030', province: 'Champasak', district: 'Phonthong'),
      PostalCode(code: '16040', province: 'Champasak', district: 'Xanasomboun'),
      PostalCode(code: '16050', province: 'Champasak', district: 'Pathoumphone'),
      PostalCode(code: '16060', province: 'Champasak', district: 'Khong'),
      PostalCode(code: '16070', province: 'Champasak', district: 'Mounlapamok'),
      PostalCode(code: '16080', province: 'Champasak', district: 'Pakxong'),
      PostalCode(code: '16090', province: 'Champasak', district: 'Soukhouma'),

      // Attapeu Province - 17XXX
      PostalCode(code: '17000', province: 'Attapeu', district: 'Xaysetha'),
      PostalCode(code: '17010', province: 'Attapeu', district: 'Sanamxay'),
      PostalCode(code: '17020', province: 'Attapeu', district: 'Sanxay'),
      PostalCode(code: '17030', province: 'Attapeu', district: 'Phouvong'),
      PostalCode(code: '17040', province: 'Attapeu', district: 'Samakhixay'),

      // Xaisomboun Province - 18XXX
      PostalCode(code: '18000', province: 'Xaisomboun', district: 'Anouvong'),
      PostalCode(code: '18010', province: 'Xaisomboun', district: 'Longxan'),
      PostalCode(code: '18020', province: 'Xaisomboun', district: 'Hom'),
      PostalCode(code: '18030', province: 'Xaisomboun', district: 'Thathom'),
    ];
  }

  // Get postal codes by province
  static List<PostalCode> getPostalCodesByProvince(String province) {
    return getAllPostalCodes()
        .where((postalCode) => postalCode.province == province)
        .toList();
  }

  // Get all unique provinces
  static List<String> getAllProvinces() {
    return getAllPostalCodes()
        .map((postalCode) => postalCode.province)
        .toSet()
        .toList()..sort();
  }

  // Search postal codes
  static List<PostalCode> searchPostalCodes(String query) {
    final lowercaseQuery = query.toLowerCase();
    return getAllPostalCodes()
        .where((postalCode) =>
            postalCode.code.toLowerCase().contains(lowercaseQuery) ||
            postalCode.province.toLowerCase().contains(lowercaseQuery) ||
            postalCode.district.toLowerCase().contains(lowercaseQuery))
        .toList();
  }
}