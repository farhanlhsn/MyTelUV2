import 'package:get/get.dart';

import '../pages/home/home_page.dart';
import '../pages/auth/login_page.dart';
import '../pages/me_page.dart';
import '../pages/auth/register_page.dart';
import '../pages/auth/register_success_page.dart';
import '../pages/auth/forgot_password_page.dart';
import '../pages/auth/reset_password_page.dart';
import '../bindings/auth_binding.dart';
import '../pages/kendaraan/registerplat.dart';
import '../pages/kendaraan/pengajuan_list_page.dart';
import '../pages/auth/otp_verification_page.dart';
import '../pages/kendaraan/resubmit_kendaraan_page.dart';
import '../pages/kendaraan/parkir/analitik_parkir.dart';
import '../pages/kendaraan/historyPengajuan/userhistoripengajuan.dart';
import '../pages/absensi/absensi_page.dart';
import '../pages/kendaraan/parkir/histori_parkir_page.dart';
import '../pages/settings/account_page.dart';
import '../pages/settings/notification_page.dart';
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
import 'auth_middleware.dart';
import 'role_middleware.dart';

class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String home = '/home';
  static const String me = '/me';
  static const String register = '/register';
  static const String registerPlat = '/register-plat';
  static const String registerSuccess = '/success';
  static const String forgotPassword = '/forgot-password';
  static const String resetPassword = '/reset-password';
  static const String resubmitKendaraan = '/resubmit-kendaraan';
  static const String pengajuanList = '/pengajuan-list';
  static const String otpVerification = '/otp-verification';
  static const String analitikKehadiran = '/analitik-kehadiran';
  static const String userHistoriPengajuan = '/user-histori-pengajuan';
  static const String absensi = '/absensi';
  static const String analitikParkir = '/analitik-parkir';
  static const String historiParkir = '/histori-parkir';
  static const String account = '/account';
  static const String notification = '/notification';
  static const String adminPengajuanList = '/admin-pengajuan-list';
  static const String adminAkademik = '/admin-akademik';
  static const String adminBiometrik = '/admin-biometrik';
  static const String adminUserManagement = '/admin-user-management';
  static const String adminAbsensiMonitoring = '/admin-absensi-monitoring';
  static const String jadwalMingguan = '/jadwal-mingguan';
  static const String formJadwalPengganti = '/form-jadwal-pengganti';
  static const String anomaliResult = '/anomali-result';
  static const String anomaliDashboard = '/anomali-dashboard';
  
  static final List<GetPage<dynamic>> pages = <GetPage<dynamic>>[
    GetPage<dynamic>(
      name: splash,
      page: () => const SplashPage(),
    ),
    GetPage<dynamic>(
      name: login,
      page: () => const LoginPage(),
      binding: AuthBinding(),
    ),
    GetPage<dynamic>(
      name: home,
      page: () => const HomePage(),
      binding: AuthBinding(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage<dynamic>(
      name: me,
      page: () => const MePage(),
      binding: AuthBinding(),
      middlewares: [AuthMiddleware()],
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
    GetPage<dynamic>(
      name: forgotPassword,
      page: () => const ForgotPasswordPage(),
      binding: AuthBinding(),
    ),
    GetPage<dynamic>(
      name: resetPassword,
      page: () => const ResetPasswordPage(),
      binding: AuthBinding(),
    ),
    GetPage<dynamic>(
      name: registerPlat, 
      page: () => const RegisterPlatPage(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage<dynamic>(
      name: resubmitKendaraan,
      page: () => const ResubmitKendaraanPage(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage<dynamic>(
      name: pengajuanList,
      page: () => const PengajuanListPage(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage<dynamic>(
      name: otpVerification,
      page: () => OtpVerificationPage(phoneNumber: Get.arguments ?? ""),
    ),
    GetPage<dynamic>(
      name: analitikKehadiran,
      page: () => const AnalitikParkirPage(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage<dynamic>(
      name: userHistoriPengajuan,
      page: () => const UserHistoriPengajuan(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage<dynamic>(
      name: absensi,
      page: () => const AbsensiPage(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage<dynamic>(
      name: analitikParkir,
      page: () => const AnalitikParkirPage(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage<dynamic>(
      name: historiParkir,
      page: () => const HistoriParkirPage(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage<dynamic>(
      name: account,
      page: () => const AccountPage(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage<dynamic>(
      name: notification,
      page: () => const NotificationPage(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage<dynamic>(
      name: adminPengajuanList,
      page: () => const AdminPengajuanListPage(),
      middlewares: [AuthMiddleware(), RoleMiddleware(const ['ADMIN'])],
    ),
    GetPage<dynamic>(
      name: adminAkademik,
      page: () => const AdminAkademikPage(),
      middlewares: [AuthMiddleware(), RoleMiddleware(const ['ADMIN'])],
    ),
    GetPage<dynamic>(
      name: adminBiometrik,
      page: () => const AdminBiometrikPage(),
      middlewares: [AuthMiddleware(), RoleMiddleware(const ['ADMIN'])],
    ),
    GetPage<dynamic>(
      name: adminUserManagement,
      page: () => const AdminUserManagementPage(),
      middlewares: [AuthMiddleware(), RoleMiddleware(const ['ADMIN'])],
    ),
    GetPage<dynamic>(
      name: adminAbsensiMonitoring,
      page: () => const AdminAbsensiMonitoringPage(),
      middlewares: [AuthMiddleware(), RoleMiddleware(const ['ADMIN'])],
    ),
    GetPage<dynamic>(
      name: jadwalMingguan,
      page: () => const JadwalMingguanPage(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage<dynamic>(
      name: formJadwalPengganti,
      page: () => const FormJadwalPenggantiPage(),
      middlewares: [AuthMiddleware(), RoleMiddleware(const ['ADMIN', 'DOSEN'])],
    ),
    GetPage<dynamic>(
      name: anomaliResult,
      page: () => const AnomaliResultPage(),
      middlewares: [AuthMiddleware(), RoleMiddleware(const ['ADMIN', 'DOSEN'])],
    ),
    GetPage<dynamic>(
      name: anomaliDashboard,
      page: () => const AnomaliDashboardPage(),
      middlewares: [AuthMiddleware(), RoleMiddleware(const ['ADMIN', 'DOSEN'])],
    ),
  ];
}
