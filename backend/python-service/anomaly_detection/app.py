import os
import traceback
from flask import Flask, request, jsonify
import pandas as pd
import numpy as np
from sklearn.ensemble import IsolationForest

app = Flask(__name__)

ANOMALY_API_KEY = os.getenv('ANOMALY_API_KEY', '')

@app.before_request
def check_api_key():
    if request.path in ['/', '/health']:
        return  # Skip auth untuk health check
    api_key = request.headers.get('X-API-Key', '')
    if ANOMALY_API_KEY and api_key != ANOMALY_API_KEY:
        return jsonify({'success': False, 'error': 'Unauthorized'}), 401


@app.route('/', methods=['GET'])
def index():
    return "✅ Anomaly Detection Service Running on Port 5003", 200

@app.route('/health', methods=['GET'])
def health():
    return jsonify({
        'status': 'healthy',
        'service': 'anomaly-detection-ai',
        'version': '1.0.0'
    }), 200

def haversine_vectorized(lat1, lon1, lat2, lon2):
    """Calculate Haversine distance in meters between two sets of coordinates"""
    try:
        lat1, lon1, lat2, lon2 = map(np.radians, [lat1, lon1, lat2, lon2])
        dlat = lat2 - lat1
        dlon = lon2 - lon1
        a = np.sin(dlat/2.0)**2 + np.cos(lat1) * np.cos(lat2) * np.sin(dlon/2.0)**2
        c = 2.0 * np.arcsin(np.sqrt(a))
        r = 6371000  # Radius of Earth in meters
        return c * r
    except Exception:
        return 0.0

@app.route('/detect-anomalies', methods=['POST'])
def detect_anomalies():
    try:
        data = request.json
        students = data.get('students', [])
        attendance_records = data.get('attendance', [])
        sessions = data.get('sessions', [])
        total_sessions = data.get('total_sessions', 1)
        threshold = data.get('threshold', 0.5)
        contamination_rate = data.get('contamination', 0.1)

        if not students:
            return jsonify({'success': True, 'count': 0, 'anomalies': []})

        # Convert ke DataFrame
        df_students = pd.DataFrame(students)
        anomalies = []

        # --- LOGIKA AI ---
        if attendance_records:
            df_attn = pd.DataFrame(attendance_records)

            # 1. Deteksi Ketidakhadiran Berulang (Statistical)
            attendance_counts = df_attn.groupby('id_user').size().reset_index(name='jumlah_hadir')
            df_analysis = pd.merge(df_students, attendance_counts, on='id_user', how='left')
            df_analysis['jumlah_hadir'] = df_analysis['jumlah_hadir'].fillna(0)
            df_analysis['attendance_rate'] = df_analysis['jumlah_hadir'] / total_sessions

            # Rule: Jika kehadiran < threshold
            chronic_absentees = df_analysis[df_analysis['attendance_rate'] < threshold]
            for _, row in chronic_absentees.iterrows():
                attn_rate = row['attendance_rate']
                # Confidence score: semakin mendekati 0% kehadiran, semakin tinggi confidence (max: 1.0)
                confidence = 1.0 - (attn_rate / threshold) if threshold > 0 else 1.0
                anomalies.append({
                    'id_user': int(row['id_user']),
                    'type_anomali': 'TIDAK_HADIR_BERULANG',
                    'confidence': round(float(confidence), 2),
                    'description': f"Kehadiran rendah: {attn_rate*100:.0f}% (Threshold: {threshold*100:.0f}%)"
                })

            # 2. Deteksi Kehadiran Ganda (Duplicate Check-ins)
            duplicates = df_attn[df_attn.duplicated(subset=['id_user', 'id_sesi'], keep=False)]
            if not duplicates.empty:
                dup_users = duplicates['id_user'].unique()
                for uid in dup_users:
                    if not any(a['id_user'] == int(uid) and a['type_anomali'] == 'KEHADIRAN_GANDA' for a in anomalies):
                        anomalies.append({
                            'id_user': int(uid),
                            'type_anomali': 'KEHADIRAN_GANDA',
                            'confidence': 1.0, # Ganda dalam sesi yang sama = 100% pasti anomali
                            'description': "Terdeteksi multiple check-in pada sesi yang sama."
                        })

            # 3. Deteksi Pola Waktu & Lokasi Tidak Wajar (Hybrid: Rule-Based & Unsupervised ML via Isolation Forest)
            if sessions:
                df_sessions = pd.DataFrame(sessions)
                df_sessions['mulai'] = pd.to_datetime(df_sessions['mulai'], utc=True)
                df_sessions['selesai'] = pd.to_datetime(df_sessions['selesai'], utc=True)
                df_sessions['durasi'] = (df_sessions['selesai'] - df_sessions['mulai']).dt.total_seconds()

                df_attn_timing = pd.merge(df_attn, df_sessions, left_on='id_sesi', right_on='id_sesi', how='inner')
                df_attn_timing['timestamp'] = pd.to_datetime(df_attn_timing['timestamp'], utc=True)
                df_attn_timing['check_in_latency'] = (df_attn_timing['timestamp'] - df_attn_timing['mulai']).dt.total_seconds()
                
                # Saring sesi dengan durasi valid
                df_attn_timing = df_attn_timing[df_attn_timing['durasi'] > 0]
                df_attn_timing['relative_timing'] = df_attn_timing['check_in_latency'] / df_attn_timing['durasi']

                # Suspicious jika check-in di 20% durasi terakhir sesi (misal: 12 menit terakhir dari 60 menit sesi)
                df_attn_timing['is_suspicious_late'] = df_attn_timing['relative_timing'] > 0.8
                
                # Hitung jarak geospasial jika koordinat absensi dan sesi tersedia
                if 'latitude_x' in df_attn_timing.columns and 'latitude_y' in df_attn_timing.columns:
                    # Filter out null coordinates to prevent calculation error
                    df_attn_timing['latitude_x'] = pd.to_numeric(df_attn_timing['latitude_x'], errors='coerce')
                    df_attn_timing['longitude_x'] = pd.to_numeric(df_attn_timing['longitude_x'], errors='coerce')
                    df_attn_timing['latitude_y'] = pd.to_numeric(df_attn_timing['latitude_y'], errors='coerce')
                    df_attn_timing['longitude_y'] = pd.to_numeric(df_attn_timing['longitude_y'], errors='coerce')
                    
                    df_attn_timing['check_in_distance'] = haversine_vectorized(
                        df_attn_timing['latitude_x'],
                        df_attn_timing['longitude_x'],
                        df_attn_timing['latitude_y'],
                        df_attn_timing['longitude_y']
                    ).fillna(0.0)
                else:
                    df_attn_timing['check_in_distance'] = 0.0

                # Integrasikan Machine Learning Unsupervised (Isolation Forest) jika jumlah data presensi cukup
                if len(df_attn_timing) >= 5:
                    try:
                        # Ekstrak features: relative_timing, check_in_latency, dan check_in_distance
                        features = ['relative_timing', 'check_in_latency', 'check_in_distance']
                        X = df_attn_timing[features].fillna(0).values
                        
                        # Train model untuk mendeteksi pencilan (outliers)
                        # Gunakan parameter kontaminasi dinamis (ensure within valid range (0, 0.5])
                        c_rate = max(0.01, min(0.5, float(contamination_rate)))
                        iso_forest = IsolationForest(contamination=c_rate, random_state=42)
                        preds = iso_forest.fit_predict(X)
                        
                        # Prediksi -1 menandakan pencilan/outlier
                        df_attn_timing['is_ml_anomalous'] = preds == -1
                        
                        # Tandai sebagai suspicious jika masuk rule-based late atau terdeteksi ML outlier
                        df_attn_timing['is_suspicious_late'] = (df_attn_timing['is_suspicious_late']) | (df_attn_timing['is_ml_anomalous'])
                    except Exception as ml_err:
                        # Tetap jalan dengan rule-based jika ML mengalami error (graceful fallback)
                        print(f"[ML WARNING] Gagal eksekusi Isolation Forest: {ml_err}. Menggunakan rule-based.")

                # Group by user untuk deteksi kecenderungan pola waktu tidak wajar
                timing_stats = df_attn_timing.groupby('id_user').agg(
                    total_checkins=('is_suspicious_late', 'count'),
                    late_checkins=('is_suspicious_late', 'sum')
                ).reset_index()

                # Rule: Minimal telah hadir 2 kali, dan >= 75% dari kehadiran tersebut berada di akhir sesi/outlier
                suspicious_timing = timing_stats[
                    (timing_stats['total_checkins'] >= 2) & 
                    ((timing_stats['late_checkins'] / timing_stats['total_checkins']) >= 0.75)
                ]

                for _, row in suspicious_timing.iterrows():
                    uid = int(row['id_user'])
                    total_c = int(row['total_checkins'])
                    late_c = int(row['late_checkins'])
                    ratio = late_c / total_c
                    
                    # Hindari duplikasi jika user sudah dideteksi TIDAK_HADIR_BERULANG (prioritaskan bolos kronis)
                    if not any(a['id_user'] == uid and a['type_anomali'] == 'TIDAK_HADIR_BERULANG' for a in anomalies):
                        anomalies.append({
                            'id_user': uid,
                            'type_anomali': 'POLA_WAKTU_TIDAK_WAJAR',
                            'confidence': round(float(ratio), 2),
                            'description': f"Terdeteksi pola check-in tidak wajar di akhir sesi atau terdeteksi ML Outlier ({late_c}/{total_c} kehadiran, rasio {ratio*100:.1f}%)."
                        })

        # Jika data absensi kosong tapi sesi sudah jalan, semua mahasiswa dianggap bolos
        elif total_sessions > 0:
             for _, row in df_students.iterrows():
                anomalies.append({
                    'id_user': int(row['id_user']),
                    'type_anomali': 'TIDAK_HADIR_BERULANG',
                    'confidence': 1.0,
                    'description': "Belum pernah hadir sama sekali."
                })

        return jsonify({
            'success': True, 
            'count': len(anomalies), 
            'anomalies': anomalies
        })

    except Exception as e:
        traceback.print_exc()  # Log ke stderr (server log)
        return jsonify({'success': False, 'error': 'Internal server error. Please check server logs.'}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5003, debug=True)
