// mcc_data.dart

class MccCode {
  final String code;
  final String category;
  final String nameEnglish;
  final String nameLao;

  const MccCode({
    required this.code,
    required this.category,
    required this.nameEnglish,
    required this.nameLao,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MccCode && other.code == code;
  }

  @override
  int get hashCode => code.hashCode;

  @override
  String toString() => '$code - $nameEnglish ($nameLao)';
}

class MccData {
  static List<MccCode> getAllMccCodes() {
    return [
      // 1. ຕົວແທນໃຫ້ບໍລິການທີ່ກ່ຽວກັບໂຮງແຮມ/Resort/Golf/Casino
      MccCode(
        code: '7011',
        category: 'Hotels/Resorts/Golf/Casino',
        nameEnglish: 'Lodging-Hotels',
        nameLao: 'ໂຮງແຮມ/ເຮືອນພັກ',
      ),
      MccCode(
        code: '7997',
        category: 'Hotels/Resorts/Golf/Casino',
        nameEnglish: 'Membership Club (Sport)',
        nameLao: 'ສູນ, ສະມາຄົມກິລາ',
      ),
      MccCode(
        code: '7992',
        category: 'Hotels/Resorts/Golf/Casino',
        nameEnglish: 'Public Golf Courses',
        nameLao: 'ສະໝາມກ໊ອບສາທາລະນະ',
      ),

      // 2. ຕົວແທນໃຫ້ບໍລິການທີ່ກ່ຽວກັບຊັບພະສິນສິນຄ້າເຄື່ອງໃຊ້ສອຍ
      MccCode(
        code: '5411',
        category: 'Grocery/Consumer Goods',
        nameEnglish: 'Grocery Stores and Supermarkets',
        nameLao: 'ສູນການຄ້າເຄື່ອງໃຊ້ສອຍ (ລວມ: ສູນຊັບພະສິນຄ້າໃຫຍ່)',
      ),

      // 3. ຕົວແທນໃຫ້ບໍລິການທີ່ກ່ຽວກັບຊັບພະສິນສິນຄ້າເຄື່ອງໄຟຟ້າ
      MccCode(
        code: '5732',
        category: 'Electronics',
        nameEnglish: 'Electronic Stores',
        nameLao: 'ສູນການຄ້າເຄື່ອງໃຊ້ໄຟຟ້າ',
      ),

      // 4. ຕົວແທນໃຫ້ບໍລິການທີ່ກ່ຽວກັບຮ້ານຂາຍເສື້ອຜ້າ
      MccCode(
        code: '5691',
        category: 'Clothing Stores',
        nameEnglish: 'Men\'s and Women\'s Clothing Stores',
        nameLao: 'ຮ້ານເສື້ອຜ້າຍິງຊາຍ',
      ),
      MccCode(
        code: '5947',
        category: 'Clothing Stores',
        nameEnglish: 'Gift',
        nameLao: 'ຮ້ານຄ້າເຄື່ອງທີ່ລະນຶກ',
      ),
      MccCode(
        code: '5977',
        category: 'Clothing Stores',
        nameEnglish: 'Cosmetic Stores',
        nameLao: 'ຮ້ານຄ້າເຄື່ອງສຳອາງ',
      ),
      MccCode(
        code: '5661',
        category: 'Clothing Stores',
        nameEnglish: 'Shoe Stores',
        nameLao: 'ຮ້ານຄ້າເກີບ',
      ),
      MccCode(
        code: '5655',
        category: 'Clothing Stores',
        nameEnglish: 'Sports and Riding Apparel Stores',
        nameLao: 'ຮ້ານຄ້າເຄື່ອງກິລາ',
      ),
      MccCode(
        code: '5621',
        category: 'Clothing Stores',
        nameEnglish: 'Women\'s Ready-To-Wear Stores',
        nameLao: 'ຮ້ານຄ້າເສື້ອຜ້າຍິງ',
      ),
      MccCode(
        code: '5641',
        category: 'Clothing Stores',
        nameEnglish: 'Children\'s and Infants\' Wear Stores',
        nameLao: 'ຮ້ານຄ້າເສື້ອຜ້າເດັກນ້ອຍ ແລະ ເດັກເກີດໃໝ່',
      ),
      MccCode(
        code: '5631',
        category: 'Clothing Stores',
        nameEnglish: 'Women\'s Accessory and Specialty Shops',
        nameLao: 'ຮ້ານຄ້າໃຊ້ປະດັບຜູ້ຍິງ',
      ),
      MccCode(
        code: '5611',
        category: 'Clothing Stores',
        nameEnglish: 'Men\'s and Boys\' Clothing and Accessories Stores',
        nameLao: 'ຮ້ານຄ້າເສື້ອຜ້າ ແລະ ປະດັບຊາຍ',
      ),

      // 5. ຕົວແທນໃຫ້ບໍລິການທີ່ກ່ຽວກັບຮ້ານອາຫານ
      MccCode(
        code: '5812',
        category: 'Restaurants/Food',
        nameEnglish: 'Eating Places and Restaurants',
        nameLao: 'ຮ້ານອາຫານ ແລະ ເຄື່ອງດື່ມ',
      ),
      MccCode(
        code: '5813',
        category: 'Restaurants/Food',
        nameEnglish: 'Drinking Places (Alcoholic Beverages)-Bar',
        nameLao: 'ຮ້ານບາ ແລະ ເຄື່ອງດື່ມ',
      ),
      MccCode(
        code: '5921',
        category: 'Restaurants/Food',
        nameEnglish: 'Package Stores - Beer',
        nameLao: 'ຮ້ານເບຍ',
      ),
      MccCode(
        code: '5814',
        category: 'Restaurants/Food',
        nameEnglish: 'Fast Food Restaurant',
        nameLao: 'ຮ້ານອາຫານຈານດ່ວນ',
      ),

      // 6. ຕົວແທນໃຫ້ບໍລິການທີ່ກ່ຽວກັບການບໍລິການສາທາລະນະ
      MccCode(
        code: '9402',
        category: 'Public Services',
        nameEnglish: 'Postal Services - Government Only',
        nameLao: 'ໄປສະນີ (ຂອງລັດ)',
      ),
      MccCode(
        code: '9399',
        category: 'Public Services',
        nameEnglish: 'Government Services-Not Elsewhere Classified',
        nameLao: 'ບໍລິການຂອງລັດ (ບຸລິມະສິດ)',
      ),
      MccCode(
        code: '9222',
        category: 'Public Services',
        nameEnglish: 'Fines',
        nameLao: 'ດ່ານສາກົນ, ຈຸດເກັບພາສີ, ຄ່າທຳນຽມ…',
      ),
      MccCode(
        code: '5541',
        category: 'Public Services',
        nameEnglish: 'Service Stations (With or without ancillary Services)',
        nameLao: 'ຈຸດບໍລິການ (ມີ ຫຼື ບໍ່ມີການບໍລິການຊ່ວຍເຫຼືອ)',
      ),

      // 7. ຕົວແທນໃຫ້ບໍລິການທີ່ກ່ຽວກັບໂຮງຮຽນ, ໂຮງໝໍ, ໄຟຟ້າ, ໄປສະນີ-ໂທລະຄົມ
      MccCode(
        code: '4900',
        category: 'Education/Healthcare/Utilities',
        nameEnglish: 'Utilities - Electric',
        nameLao: 'ບໍລິການອຳນວຍຄວາມສະດວກ: ໄຟຟ້າ',
      ),
      MccCode(
        code: '4814',
        category: 'Education/Healthcare/Utilities',
        nameEnglish: 'Telecommunication Services',
        nameLao: 'ບໍລິການໄປສະນີ',
      ),
      MccCode(
        code: '8220',
        category: 'Education/Healthcare/Utilities',
        nameEnglish: 'Colleges',
        nameLao: 'ມະຫາວິທະຍາໄລ, ວິທະຍາໄລ',
      ),
      MccCode(
        code: '8211',
        category: 'Education/Healthcare/Utilities',
        nameEnglish: 'Elementary and Secondary Schools',
        nameLao: 'ໂຮງຮຽນອານຸບານ, ອາຊີວະ',
      ),
      MccCode(
        code: '8299',
        category: 'Education/Healthcare/Utilities',
        nameEnglish: 'Schools and Educational Services-Not Elsewhere Classified',
        nameLao: 'ໂຮງຮຽນ ແລະ ບໍລິການທາງການສຶກສາ',
      ),
      MccCode(
        code: '8241',
        category: 'Education/Healthcare/Utilities',
        nameEnglish: 'Correspondence Schools',
        nameLao: 'ໂຮງຮຽນ',
      ),
      MccCode(
        code: '8244',
        category: 'Education/Healthcare/Utilities',
        nameEnglish: 'Business and Secretarial Schools',
        nameLao: 'ໂຮງຮຽນ',
      ),
      MccCode(
        code: '8351',
        category: 'Education/Healthcare/Utilities',
        nameEnglish: 'Child Care Services',
        nameLao: 'ບໍລິການລ້ຽງເດັກ',
      ),
      MccCode(
        code: '8062',
        category: 'Education/Healthcare/Utilities',
        nameEnglish: 'Hospitals',
        nameLao: 'ໂຮງໝໍ',
      ),

      // 8. ຕົວແທນໃຫ້ບໍລິການທີ່ກ່ຽວກັບຂົນສົ່ງ
      MccCode(
        code: '4789',
        category: 'Transportation',
        nameEnglish: 'Transportation Services-Not Elsewhere Classified',
        nameLao: 'ບໍລິການຂົນສົ່ງ',
      ),
      MccCode(
        code: '4131',
        category: 'Transportation',
        nameEnglish: 'Bus Lines',
        nameLao: 'ລົດເມ',
      ),
      MccCode(
        code: '4121',
        category: 'Transportation',
        nameEnglish: 'Taxicabs and Limousines',
        nameLao: 'ລົດແທກຊີ',
      ),
      MccCode(
        code: '4722',
        category: 'Transportation',
        nameEnglish: 'Travel Agencies and Tour Operator',
        nameLao: 'ຕົວແທນທ່ອງທ່ຽວ, ບໍລິການນຳທ່ຽວ',
      ),
      MccCode(
        code: '4511',
        category: 'Transportation',
        nameEnglish: 'Airlines and Air Carriers',
        nameLao: 'ຂົນສົ່ງທາງອາກາດ',
      ),

      // 9. ໝວດຕົວແທນໃຫ້ບໍລິການທີ່ກ່ຽວກັບການຢາ
      MccCode(
        code: '5912',
        category: 'Pharmacy/Medical',
        nameEnglish: 'Drug Stores and Pharmacies',
        nameLao: 'ຮ້ານຂາຍຢາ',
      ),
      MccCode(
        code: '8071',
        category: 'Pharmacy/Medical',
        nameEnglish: 'Medical and Dental Laboratories',
        nameLao: 'ຫ້ອງທົດລອງທາງການແພດ ແລະ ການຢາ',
      ),
      MccCode(
        code: '8099',
        category: 'Pharmacy/Medical',
        nameEnglish: 'Medical Services and Health Practioners',
        nameLao: 'ບໍລິການການແພດ',
      ),
      MccCode(
        code: '5047',
        category: 'Pharmacy/Medical',
        nameEnglish: 'Dental/Laboratory/Medical',
        nameLao: 'ປິ່ນປົວແຂ້ວ/ຫ້ອງທົດລອງ/ການແພດ',
      ),
      MccCode(
        code: '5122',
        category: 'Pharmacy/Medical',
        nameEnglish: 'Drugs',
        nameLao: 'ຢາ',
      ),
      MccCode(
        code: '5169',
        category: 'Pharmacy/Medical',
        nameEnglish: 'Chemicals and Allied Products',
        nameLao: 'ເຄມີ ແລະ ບັນດາຜະລິດຕະພັນທີ່ກ່ຽວຂ້ອງ',
      ),
      MccCode(
        code: '8734',
        category: 'Pharmacy/Medical',
        nameEnglish: 'Testing Laboratories (Non-Medical?)',
        nameLao: 'ຫ້ອງທົດລອງ',
      ),

      // 10. ຕົວແທນໃຫ້ບໍລິການທີ່ກ່ຽວກັບອື່ນໆ
      MccCode(
        code: '0000',
        category: 'Others',
        nameEnglish: 'Other Services',
        nameLao: 'ບໍລິການອື່ນໆ',
      ),
    ];
  }

  // Get MCC codes by category
  static List<MccCode> getMccCodesByCategory(String category) {
    return getAllMccCodes()
        .where((mccCode) => mccCode.category == category)
        .toList();
  }

  // Get all unique categories
  static List<String> getAllCategories() {
    return getAllMccCodes()
        .map((mccCode) => mccCode.category)
        .toSet()
        .toList()..sort();
  }

  // Search MCC codes
  static List<MccCode> searchMccCodes(String query) {
    final lowercaseQuery = query.toLowerCase();
    return getAllMccCodes()
        .where((mccCode) =>
            mccCode.code.toLowerCase().contains(lowercaseQuery) ||
            mccCode.category.toLowerCase().contains(lowercaseQuery) ||
            mccCode.nameEnglish.toLowerCase().contains(lowercaseQuery) ||
            mccCode.nameLao.toLowerCase().contains(lowercaseQuery))
        .toList();
  }

  // Get MCC code by code
  static MccCode? getMccByCode(String code) {
    try {
      return getAllMccCodes().firstWhere((mccCode) => mccCode.code == code);
    } catch (e) {
      return null;
    }
  }
}