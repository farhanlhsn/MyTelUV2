import 'package:get/get.dart';

import '../pages/home/home_page.dart';
import '../pages/auth/login_page.dart';
import '../pages/me_page.dart';
import '../pages/auth/register_page.dart';
import '../pages/auth/register_success_page.dart';
import '../bindings/auth_binding.dart';
import '../pages/kendaraan/registerplat.dart';
import '../pages/Punya_Raja/registerplat/pengajuan_list_page.dart';
import '../pages/Punya_Raja/auth/otp_verification_page.dart';
import '../pages/Punya_Raja/analitik/analitikkehadiran.dart';
import '../pages/kendaraan/historyPengajuan/userhistoripengajuan.dart';

class AppRoutes {
  static const String login = '/login';
  static const String home = '/home';
  static const String me = '/me';
  static const String register = '/register';
  static const String registerPlat = '/';
  static const String registerSuccess = '/success';
  static const String pengajuanList = '/pengajuan-list';
  static const String otpVerification = '/otp-verification';
  static const String analitikKehadiran = '/analitik-kehadiran';
  static const String userHistoriPengajuan = '/user-histori-pengajuan';
  static final List<GetPage<dynamic>> pages = <GetPage<dynamic>>[
    GetPage<dynamic>(
      name: login,
      page: () => const LoginPage(),
      binding: AuthBinding(),
    ),
    GetPage<dynamic>(
      name: home,
      page: () => const HomePage(),
      binding: AuthBinding(),
    ),
    GetPage<dynamic>(
      name: me,
      page: () => const MePage(),
      binding: AuthBinding(),
    ),
    GetPage<dynamic>(
      name: register,
      page: () => const RegisterPage(),
      binding: AuthBinding(),
    ),
    GetPage<dynamic>(
      name: registerSuccess,
      page: () => const RegisterSuccessPage(),
    ),
    GetPage<dynamic>(name: registerPlat, page: () => const RegisterPlatPage()),
    GetPage<dynamic>(
      name: pengajuanList,
      page: () => const PengajuanListPage(),
    ),
    GetPage<dynamic>(
      name: otpVerification,
      page: () => OtpVerificationPage(phoneNumber: Get.arguments ?? ""),
    ),
    GetPage<dynamic>(
      name: analitikKehadiran,
      page: () => const AnalitikKehadiranPage(),
    ),
    GetPage<dynamic>(
      name: userHistoriPengajuan,
      page: () => const UserHistoriPengajuan(),
    ),
  ];
}
