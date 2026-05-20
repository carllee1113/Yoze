import 'package:flutter/material.dart';

class UserGuideScreen extends StatelessWidget {
  const UserGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('使用說明')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _GuideHeader(),
          _GuideSection(
            title: '1. 今日服藥進度',
            description: '主頁會按服藥時間分成大卡。每一張大卡代表一次服藥時間，勾選「全部」代表該次藥物已全部完成。',
            snapshot: _HomeSnapshot(),
          ),
          _GuideSection(
            title: '2. 新增藥物',
            description: '按右下角「+」進入藥物設定；按相機按鈕可直接拍照新增。你可以一次加入多種藥物。',
            snapshot: _AddSnapshot(),
          ),
          _GuideSection(
            title: '3. 拍照或手動輸入',
            description:
                '拍照新增會先做 OCR 識別，識別後仍可在藥物設定頁檢查及修正。手動新增可直接輸入藥名、劑量、每日次數及每次份量。',
            snapshot: _InputSnapshot(),
          ),
          _GuideSection(
            title: '4. 藥物設定與編輯',
            description: '每種藥物只顯示一次，即使每日有多個提醒時間。按「編輯」可修改資料、加入相片、從相簿選相或移除相片。',
            snapshot: _SettingsSnapshot(),
          ),
          _GuideSection(
            title: '5. 藥物相片',
            description: '在藥物設定頁按一下藥物相片，可放大查看藥物標籤及藥物外觀。你可以用手指縮放圖片。',
            snapshot: _PhotoSnapshot(),
          ),
          _GuideSection(
            title: '6. 封存與刪除',
            description: '「封存」會保留曾服用記錄，但不再出現在提醒頁。「刪除」會永久移除資料，如想保存記錄請用封存。',
            snapshot: _ArchiveSnapshot(),
          ),
          _GuideSection(
            title: '7. 歷史紀錄',
            description: '歷史頁用月曆顯示完成度：100% 為綠色剔，80% 或以上為藍色剔，其餘為紅色圓點。',
            snapshot: _HistorySnapshot(),
          ),
          _GuideSection(
            title: '8. 提醒聲音',
            description: '完成服藥時，App 會盡量使用廣東話語音。若手機沒有廣東話 TTS，系統可能自動退回中文或普通話聲音。',
            snapshot: _VoiceSnapshot(),
          ),
          SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _GuideHeader extends StatelessWidget {
  const _GuideHeader();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.amber.shade50,
      child: const Padding(
        padding: EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'YOZE 藥師快速指南',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
            ),
            SizedBox(height: 8),
            Text(
              '這裡教你新增藥物、設定提醒、完成服藥、查看歷史，以及管理已停用藥物。',
              style: TextStyle(fontSize: 15, height: 1.45),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuideSection extends StatelessWidget {
  final String title;
  final String description;
  final Widget snapshot;

  const _GuideSection({
    required this.title,
    required this.description,
    required this.snapshot,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(top: 14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: const TextStyle(fontSize: 14, height: 1.45),
            ),
            const SizedBox(height: 14),
            snapshot,
          ],
        ),
      ),
    );
  }
}

class _PhoneFrame extends StatelessWidget {
  final Widget child;

  const _PhoneFrame({required this.child});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 260,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade900,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _HomeSnapshot extends StatelessWidget {
  const _HomeSnapshot();

  @override
  Widget build(BuildContext context) {
    return _PhoneFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '🐱 今天服藥進度',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(value: 0.5, color: Colors.amber.shade700),
          const SizedBox(height: 12),
          _MiniDoseCard(time: '08:00 第1次，共2粒/份量'),
          _MiniMedicineLine(code: '01', name: 'PARACETAMOL', done: true),
          _MiniMedicineLine(code: '02', name: '藥水', done: false),
        ],
      ),
    );
  }
}

class _AddSnapshot extends StatelessWidget {
  const _AddSnapshot();

  @override
  Widget build(BuildContext context) {
    return _PhoneFrame(
      child: Column(
        children: [
          Row(
            children: [
              FloatingActionButton.small(
                heroTag: null,
                onPressed: null,
                child: const Icon(Icons.camera_alt),
              ),
              const Spacer(),
              FloatingActionButton.small(
                heroTag: null,
                onPressed: null,
                child: const Icon(Icons.add),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text('相機：拍照新增\n+：進入藥物設定', textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _InputSnapshot extends StatelessWidget {
  const _InputSnapshot();

  @override
  Widget build(BuildContext context) {
    return _PhoneFrame(
      child: Column(
        children: [
          _MiniButton(icon: Icons.edit_note, label: '手動新增'),
          const SizedBox(height: 8),
          _MiniButton(icon: Icons.camera_alt, label: '拍照新增'),
          const SizedBox(height: 10),
          const Text('每日 1 次，每次 1 份量', style: TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

class _SettingsSnapshot extends StatelessWidget {
  const _SettingsSnapshot();

  @override
  Widget build(BuildContext context) {
    return _PhoneFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '01 PARACETAMOL',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const Text('08:00、12:00、16:00 服用', style: TextStyle(fontSize: 12)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            children: [
              Chip(
                label: const Text('編輯'),
                backgroundColor: Colors.blue.shade50,
              ),
              const Chip(label: Text('封存')),
              const Chip(label: Text('刪除')),
            ],
          ),
        ],
      ),
    );
  }
}

class _PhotoSnapshot extends StatelessWidget {
  const _PhotoSnapshot();

  @override
  Widget build(BuildContext context) {
    return _PhoneFrame(
      child: Column(
        children: [
          Container(
            height: 120,
            decoration: BoxDecoration(
              color: Colors.amber.shade100,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.amber.shade700),
            ),
            child: const Center(child: Icon(Icons.zoom_out_map, size: 42)),
          ),
          const SizedBox(height: 8),
          const Text('按相片可放大查看', style: TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

class _ArchiveSnapshot extends StatelessWidget {
  const _ArchiveSnapshot();

  @override
  Widget build(BuildContext context) {
    return _PhoneFrame(
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('目前服用中'),
          SizedBox(height: 8),
          Text('01 藥物 A'),
          Divider(),
          Text('已封存 (2)'),
          Text('03 舊藥物'),
        ],
      ),
    );
  }
}

class _HistorySnapshot extends StatelessWidget {
  const _HistorySnapshot();

  @override
  Widget build(BuildContext context) {
    return _PhoneFrame(
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _DayBox(label: '1', icon: Icons.check_circle, color: Colors.green),
          _DayBox(label: '2', icon: Icons.check_circle, color: Colors.blue),
          _DayBox(label: '3', icon: Icons.circle, color: Colors.red),
          _DayBox(label: '4', icon: Icons.remove, color: Colors.grey),
        ],
      ),
    );
  }
}

class _VoiceSnapshot extends StatelessWidget {
  const _VoiceSnapshot();

  @override
  Widget build(BuildContext context) {
    return _PhoneFrame(
      child: const Column(
        children: [
          Icon(Icons.volume_up, size: 44, color: Colors.orange),
          SizedBox(height: 8),
          Text('廣東話語音提示', style: TextStyle(fontWeight: FontWeight.w800)),
          Text('完成服藥後播放', style: TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

class _MiniDoseCard extends StatelessWidget {
  final String time;

  const _MiniDoseCard({required this.time});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(time, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}

class _MiniMedicineLine extends StatelessWidget {
  final String code;
  final String name;
  final bool done;

  const _MiniMedicineLine({
    required this.code,
    required this.name,
    required this.done,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Text('$code $name', style: const TextStyle(fontSize: 12)),
          const Spacer(),
          Text(done ? '完成' : '等待中', style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

class _MiniButton extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MiniButton({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade400),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [Icon(icon, size: 18), const SizedBox(width: 8), Text(label)],
      ),
    );
  }
}

class _DayBox extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;

  const _DayBox({required this.label, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: const TextStyle(fontSize: 11)),
          Icon(icon, color: color, size: 16),
        ],
      ),
    );
  }
}
