import pathlib
import subprocess
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]


class ScriptOutputDecoderTests(unittest.TestCase):
    def test_every_byte_boundary_preserves_chinese_progress_and_final_line(self):
        source = (ROOT / 'Sources/ScriptOutputDecoder.swift').read_text()
        harness = r'''
let expected = "[PROGRESS:35] 正在适配并验签\n已安装：第三实例\n最后一行"
let bytes = Array(expected.utf8)
for boundary in 0...bytes.count {
    var decoder = ScriptOutputDecoder()
    let first = decoder.append(Data(bytes[..<boundary]))
    assert(first.isEmpty || first.hasSuffix("\n"))
    let second = decoder.append(Data(bytes[boundary...]))
    let tail = decoder.append(Data(), finishing: true)
    assert(first + second + tail == expected, "split at \(boundary)")
}
var decoder = ScriptOutputDecoder()
var received = ""
for byte in bytes { received += decoder.append(Data([byte])) }
received += decoder.append(Data(), finishing: true)
assert(received == expected)
'''
        with tempfile.TemporaryDirectory() as directory:
            path = pathlib.Path(directory) / 'main.swift'
            path.write_text(source + harness)
            result = subprocess.run(['swift', str(path)], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
