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


if __name__ == "__main__":
    unittest.main()
