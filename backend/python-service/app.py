from flask import Flask, request, jsonify
import pandas as pd
import numpy as np

app = Flask(__name__)

@app.route('/', methods=['GET'])
def index():
    return "✅ Anomaly Detection Service Running on Port 5003", 200

@app.route('/detect-anomalies', methods=['POST'])
def detect_anomalies():
    try:
        data = request.json
        students = data.get('students', [])
        attendance_records = data.get('attendance', [])
        total_sessions = data.get('total_sessions', 1)

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

            # Rule: Jika kehadiran < 50%
            chronic_absentees = df_analysis[df_analysis['attendance_rate'] < 0.5]
            for _, row in chronic_absentees.iterrows():
                anomalies.append({
                    'id_user': int(row['id_user']),
                    'type_anomali': 'TIDAK_HADIR_BERULANG',
                    'description': f"Kehadiran rendah: {row['attendance_rate']*100:.0f}%"
                })

            # 2. Deteksi Kehadiran Ganda
            duplicates = df_attn[df_attn.duplicated(subset=['id_user', 'id_sesi'], keep=False)]
            if not duplicates.empty:
                dup_users = duplicates['id_user'].unique()
                for uid in dup_users:
                    # Cek duplikasi agar tidak double insert
                    if not any(a['id_user'] == int(uid) and a['type_anomali'] == 'KEHADIRAN_GANDA' for a in anomalies):
                        anomalies.append({
                            'id_user': int(uid),
                            'type_anomali': 'KEHADIRAN_GANDA',
                            'description': "Terdeteksi multiple check-in pada sesi yang sama."
                        })

        # Jika data absensi kosong tapi sesi sudah jalan, semua mahasiswa dianggap bolos
        elif total_sessions > 0:
             for _, row in df_students.iterrows():
                anomalies.append({
                    'id_user': int(row['id_user']),
                    'type_anomali': 'TIDAK_HADIR_BERULANG',
                    'description': "Belum pernah hadir sama sekali."
                })

        return jsonify({
            'success': True, 
            'count': len(anomalies), 
            'anomalies': anomalies
        })

    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5003, debug=True)