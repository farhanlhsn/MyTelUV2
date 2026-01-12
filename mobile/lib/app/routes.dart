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
import '../pages/Punya_Raja/analitik/analitik_parkir.dart';
import '../pages/kendaraan/historyPengajuan/userhistoripengajuan.dart';
import '../pages/absensi/absensi_page.dart';
import '../pages/Punya_Raja/analitik/analitik_parkir.dart';
import '../pages/kendaraan/parkir/histori_parkir_page.dart';
import '../pages/settings/account_page.dart';
import '../pages/settings/notification_page.dart';
<<<<<<< Updated upstream
=======
import '../pages/kendaraan/admin/admin_pengajuan_list_page.dart';
import '../pages/admin/admin_akademik_page.dart';
import '../pages/admin/admin_biometrik_page.dart';
import '../pages/admin/admin_user_management_page.dart';
import '../pages/admin/admin_absensi_monitoring_page.dart';
import '../pages/splash_page.dart';
import '../pages/jadwal/jadwal_mingguan_page.dart';
import '../pages/jadwal/form_jadwal_pengganti_page.dart';
import '../pages/admin/admin_anomali_result_page.dart';
import '../pages/admin/anomali_dashboard_page.dart';

>>>>>>> Stashed changes
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
  static const String absensi = '/absensi';
  static const String analitikParkir = '/analitik-parkir';
  static const String historiParkir = '/histori-parkir';
  static const String account = '/account';
  static const String notification = '/notification';
<<<<<<< Updated upstream
=======
  static const String adminPengajuanList = '/admin-pengajuan-list';
  static const String adminAkademik = '/admin-akademik';
  static const String adminBiometrik = '/admin-biometrik';
  static const String adminUserManagement = '/admin-user-management';
  static const String adminAbsensiMonitoring = '/admin-absensi-monitoring';
  static const String jadwalMingguan = '/jadwal-mingguan';
  static const String formJadwalPengganti = '/form-jadwal-pengganti';
  static const String anomaliResult = '/anomali-result';
  static const String anomaliDashboard = '/anomali-dashboard';
  
>>>>>>> Stashed changes
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
      page: () => const AnalitikParkirPage(),
    ),
    GetPage<dynamic>(
      name: userHistoriPengajuan,
      page: () => const UserHistoriPengajuan(),
    ),
    GetPage<dynamic>(
      name: absensi,
      page: () => const AbsensiPage(),
    ),
    GetPage<dynamic>(
      name: analitikParkir,
      page: () => const AnalitikParkirPage(),
    ),
    GetPage<dynamic>(
      name: historiParkir,
      page: () => const HistoriParkirPage(),
    ),
    GetPage<dynamic>(
      name: account,
      page: () => const AccountPage(),
    ),
    GetPage<dynamic>(
      name: notification,
      page: () => const NotificationPage(),
<<<<<<< Updated upstream
    )
=======
    ),
    GetPage<dynamic>(
      name: adminPengajuanList,
      page: () => const AdminPengajuanListPage(),
    ),
    GetPage<dynamic>(
      name: adminAkademik,
      page: () => const AdminAkademikPage(),
    ),
    GetPage<dynamic>(
      name: adminBiometrik,
      page: () => const AdminBiometrikPage(),
    ),
    GetPage<dynamic>(
      name: adminUserManagement,
      page: () => const AdminUserManagementPage(),
    ),
    GetPage<dynamic>(
      name: adminAbsensiMonitoring,
      page: () => const AdminAbsensiMonitoringPage(),
    ),
    GetPage<dynamic>(
      name: jadwalMingguan,
      page: () => const JadwalMingguanPage(),
    ),
    GetPage<dynamic>(
      name: formJadwalPengganti,
      page: () => const FormJadwalPenggantiPage(),
    ),
    GetPage<dynamic>(
      name: anomaliResult,
      page: () => const AnomaliResultPage(),
    ),
    GetPage<dynamic>(
      name: anomaliDashboard,
      page: () => const AnomaliDashboardPage(),
    ),
>>>>>>> Stashed changes
  ];
}
