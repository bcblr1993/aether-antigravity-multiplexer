import json
import os
import tempfile
import unittest


class TestMetadataAndStorage(unittest.TestCase):
    def setUp(self):
        self.test_dir = tempfile.TemporaryDirectory()
        self.meta_file = os.path.join(self.test_dir.name, "instances_meta.json")

    def tearDown(self):
        self.test_dir.cleanup()

    def test_metadata_serialization_roundtrip(self):
        sample_meta = {
            "com.google.antigravity": {
                "nickname": "主应用",
                "tag": "TB、AetherRoute",
                "tagColor": "indigo",
                "notes": "生产环境主力实例\n映射端口 8080\n请勿随意清空缓存"
            },
            "com.google.antigravity.clone.1": {
                "nickname": "后端测试",
                "tag": "微服务后端",
                "tagColor": "green",
                "notes": "feature/branch-auth"
            }
        }

        with open(self.meta_file, "w", encoding="utf-8") as f:
            json.dump(sample_meta, f, ensure_ascii=False, indent=2)

        self.assertTrue(os.path.exists(self.meta_file))

        with open(self.meta_file, "r", encoding="utf-8") as f:
            loaded = json.load(f)

        self.assertEqual(loaded, sample_meta)
        self.assertEqual(loaded["com.google.antigravity"]["tagColor"], "indigo")
        self.assertIn("\n", loaded["com.google.antigravity"]["notes"])

    def test_disk_usage_calculation(self):
        # Create a mock instance workspace
        ws_dir = os.path.join(self.test_dir.name, "mock_workspace")
        os.makedirs(ws_dir, exist_ok=True)

        f1 = os.path.join(ws_dir, "file1.bin")
        f2 = os.path.join(ws_dir, "file2.bin")
        with open(f1, "wb") as f:
            f.write(b"x" * 1024 * 100)  # 100 KB
        with open(f2, "wb") as f:
            f.write(b"x" * 1024 * 200)  # 200 KB

        total_bytes = 0
        for root, _, files in os.walk(ws_dir):
            for file in files:
                total_bytes += os.path.getsize(os.path.join(root, file))

        self.assertEqual(total_bytes, 307200)

    def test_empty_meta_defaults(self):
        empty_meta = {
            "nickname": "",
            "tag": "",
            "tagColor": "blue",
            "notes": ""
        }
        has_custom = bool(empty_meta["nickname"].strip() or empty_meta["tag"].strip() or empty_meta["notes"].strip())
        self.assertFalse(has_custom)

        custom_meta = {
            "nickname": "Test",
            "tag": "",
            "tagColor": "blue",
            "notes": ""
        }
        has_custom = bool(custom_meta["nickname"].strip() or custom_meta["tag"].strip() or custom_meta["notes"].strip())
        self.assertTrue(has_custom)

    def test_task_history_serialization_roundtrip(self):
        history_file = os.path.join(self.test_dir.name, "task_history.json")
        sample_history = [
            {
                "id": "A1B2C3D4-E5F6-7890-ABCD-EF1234567890",
                "instanceID": "local.antigravity.second",
                "instanceName": "Antigravity 2",
                "instanceNickname": "后端自动化测试",
                "isOriginal": False,
                "category": "completed",
                "actionSummary": "修复了 12 个单元测试用例并通过 regression",
                "workspace": "/Users/developer/backend",
                "stepIndex": 42,
                "timestamp": "2026-10-14T02:30:00Z",
                "durationSeconds": 84.5
            },
            {
                "id": "B2C3D4E5-F6A1-0987-FEDC-BA0987654321",
                "instanceID": "com.google.antigravity",
                "instanceName": "Antigravity",
                "instanceNickname": "官方主实例",
                "isOriginal": True,
                "category": "needsAttention",
                "actionSummary": "等待用户确认是否执行远程数据库迁移",
                "workspace": "/Users/developer/production",
                "stepIndex": 15,
                "timestamp": "2026-10-14T02:35:10Z",
                "durationSeconds": 12.0
            }
        ]

        with open(history_file, "w", encoding="utf-8") as f:
            json.dump(sample_history, f, ensure_ascii=False, indent=2)

        self.assertTrue(os.path.exists(history_file))

        with open(history_file, "r", encoding="utf-8") as f:
            loaded = json.load(f)

        self.assertEqual(len(loaded), 2)
        self.assertEqual(loaded[0]["category"], "completed")
        self.assertEqual(loaded[0]["durationSeconds"], 84.5)
        self.assertEqual(loaded[1]["instanceNickname"], "官方主实例")
        self.assertTrue(loaded[1]["isOriginal"])

    def test_task_duration_formatting(self):
        def format_duration(seconds):
            if seconds is None or seconds <= 0:
                return None
            total = int(seconds)
            if total < 60:
                return f"{max(1, total)} 秒"
            else:
                mins = total // 60
                secs = total % 60
                return f"{mins} 分 {secs} 秒" if secs > 0 else f"{mins} 分钟"

        self.assertIsNone(format_duration(None))
        self.assertIsNone(format_duration(0))
        self.assertEqual(format_duration(5), "5 秒")
        self.assertEqual(format_duration(60), "1 分钟")
        self.assertEqual(format_duration(84), "1 分 24 秒")
        self.assertEqual(format_duration(3600), "60 分钟")


if __name__ == "__main__":
    unittest.main()
