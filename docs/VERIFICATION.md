# ผลตรวจ 2026-10-03

สภาพแวดล้อม: macOS 26.5.2, Apple Silicon arm64, Swift 6.3.3 (Command Line Tools), deployment target macOS 14

ผ่าน:

- Debug build และ release app bundle
- `swift run WiFiCoreChecks`: 5 กลุ่มตรวจ ครอบคลุม band/frequency, RSSI boundaries, CSV escaping/formula injection, survey round-trip/schema/coordinates และ SNR ที่ข้อมูลไม่ครบ
- Info.plist lint และ codesign strict verification (ad-hoc; ไม่ใช่ Developer ID notarization)
- เปิดหน้าต่าง SwiftUI จริงและตรวจภาพหน้าภาพรวม/สำรวจ พร้อมตรวจ navigation ครบ 5 หน้า
- CoreWLAN อ่าน RSSI, noise, rate และช่อง 2.4 GHz ที่เชื่อมต่อจริง
- สแกนจริงพบ 5 AP ทั้ง 2.4 และ 5 GHz; SSID/BSSID ไม่เปิดเผยเมื่อยังไม่ได้อนุญาต Location
- ระบบรายงาน adapter รองรับ 2.4, 5 และ 6 GHz
- คลิก canvas แล้วอ่าน RSSI ใหม่ บันทึก 1 จุดจริง; ตรวจไฟล์บนดิสก์ว่ามีพิกัดในช่วง 0…1 และค่าระดับสัญญาณ
- ปิด/เปิดแอปซ้ำ จุดสำรวจเดิมกลับมาครบ และส่งออก JSON ผ่าน Save dialog ได้จริง ตรวจไฟล์ส่งออกว่ามีจุดวัดครบ
- กดตรวจเครือข่ายจาก UI: พบ default route, gateway ตอบ ICMP, DNS ตอบ และได้รับ HTTPS response

ยังไม่ยืนยัน:

- AP 6 GHz จริง, Wi-Fi 7/802.11be จริง, 320 MHz/MLO (public API ไม่เปิดครบ)
- การอนุญาต Location Services / SSID-BSSID หลังอนุญาต โดยผู้ใช้ยังไม่ได้ให้สิทธิ์
- Intel build และ macOS 14/15 runtime (build นี้เป็น arm64 บน macOS 26)
- ทุกสภาวะ failure บนอุปกรณ์จริง เช่น Wi-Fi ปิด, VPN, DNS เสีย และ roaming ระหว่างหลาย AP
- dialog นำเข้าภาพ/โครงการ และการเปลี่ยนขนาดภาพแผนผังทุกอัตราส่วน (ทดสอบ serialization ใน core และ JSON export dialog แล้ว)

ค่าที่พบเป็นเพียง snapshot ของสภาพเครือข่าย ณ เวลาทดสอบ ไม่ใช้รับรอง coverage หรือคุณภาพ Wi-Fi ในพื้นที่ทั้งหมด

## รุ่น 1.1 — ตรวจเพิ่มเติม 2026-10-03

- Debug/release build ผ่านหลังเพิ่ม SceneKit renderer และธีม Signal Studio
- Core checks ผ่าน 7 กลุ่ม รวม freshness LIVE/PAUSED/STALE/WAITING และการแปลงตำแหน่ง/ความสูงใน 3D
- ตรวจภาพจริงของภาพรวม, Signal Space 3D และหน้าเครือข่าย: สี/แท่ง 3D มาจากผล CoreWLAN จริงและมี AP snapshot timestamp
- ยืนยันการอ่านสดระหว่างสแกน: history ได้หลายตัวอย่างก่อนผลสแกนรอบใหม่ แยก worker สแกนจากการอ่านลิงก์แล้ว
- กดปิด Live แล้ว UI เปลี่ยนเป็น PAUSED และอายุข้อมูลเพิ่มขึ้น
- ตรวจการแสดง empty state ของ 3D survey เมื่อไม่มีจุด
- ปรับมุมกล้องเริ่มต้นและขนาดตัวเลขหลังตรวจภาพจริง แล้ว build release ใหม่
- ยังไม่ได้ยืนยันด้วย UI ครบทุก gesture (หมุน/ซูม/reset/hit selection), โหมด Reduce Motion และภาพแผนผังทุกอัตราส่วน; ผลทดสอบรอบนี้ไม่ใช่ performance benchmark
- ไฟล์โครงการยังใช้ schema version 1 ไม่มีการ migration/ล้างข้อมูลโดยตัวอัปเดต

## รุ่น 1.2 — ตัวเลือกกราฟเชิงเส้น / 3D

- Debug และ release build ผ่าน พร้อมตรวจ codesign ของ app bundle
- เพิ่ม segmented picker ในภาพรวมและ Signal Space ใช้ AppStorage key เดียวกันเพื่อจำตัวเลือก
- กราฟเส้นลิงก์ใช้ history เดิม; กราฟเส้น survey ใช้จุดจริงล่าสุดสูงสุด 300 จุด มุมมองที่ไม่ได้เลือกถูกถอดออกจาก view tree
- การเปลี่ยนครั้งนี้ไม่แก้ schema หรือกระบวนการอ่าน/บันทึกข้อมูล
- ยังไม่ได้ทดสอบคลิกสลับและเปิดแอปซ้ำผ่าน UI สำหรับรุ่น 1.2

## รุ่น 1.3 — คุณภาพ เหตุการณ์ และการจัดการผลสแกน

- Debug/release build ผ่าน; Core checks ผ่าน 11 กลุ่ม
- เพิ่มการตรวจค่าเฉลี่ย/ส่วนเบี่ยงเบนและ missing RSSI, เกณฑ์อ่อน 3 ตัวอย่าง, hysteresis ฟื้นตัว, baseline หลังช่องว่างเวลา, BSSID ที่ซ่อน/ต่างกันเฉพาะตัวพิมพ์, เปลี่ยน AP/channel, ลำดับ RSSI ที่ค่าหายอยู่ท้าย และ CSV ประวัติ/เหตุการณ์
- ตรวจภาพจริงด้วย QA app ที่ใช้ bundle identifier แยกจากแอปหลัก: หน้าคุณภาพแสดงค่าจาก CoreWLAN จริงและสถิติอัปเดต; เปลี่ยนเกณฑ์ด้วย stepper แล้วตัวเลขสรุปใช้เกณฑ์ใหม่
- กดสลับ 3D → กราฟเชิงเส้นสำเร็จ RSSI/Noise แสดงแยกเส้น และหน้า Signal Space ใช้ตัวเลือกเดียวกับภาพรวมพร้อมประวัติเดิม
- ไม่ทำให้สัญญาณจริงอ่อนหรือเปลี่ยน router เพื่อทดสอบ; เหตุการณ์อ่อน/ฟื้นตัว/roaming ทดสอบด้วยชุดข้อมูลควบคุมใน core
- ยังไม่ทดสอบกับ AP 6 GHz/7 จริงหรือยืนยันสาเหตุของปัญหาเครือข่าย
- ปิด/เปิด QA app ใหม่แล้วยังคงกราฟเชิงเส้นและเกณฑ์ −69 dBm ที่ตั้งไว้; การตั้งค่าทดสอบอยู่ใน preferences ของ QA เท่านั้น

## รุ่น 1.4 — รูปแบบงาน บันทึกรอบวัด และเปรียบเทียบ

- Core checks ผ่าน 14 กลุ่ม รวม session round-trip, schema/time/duplicate-ID validation, การเปรียบเทียบด้วยเกณฑ์ร่วม, atomic archive save/reopen/overwrite และการข้ามไฟล์เสียโดยไม่ลบต้นฉบับ
- Debug/release build และ codesign strict verification ผ่าน
- ตรวจภาพจริงของหน้าเริ่มต้น 4 รูปแบบการใช้งานด้วย QA bundle ที่มีคลัง Sessions แยกจากคลังหลัก
- กดเริ่มบันทึกผ่าน UI ด้วย Wi-Fi จริง เห็นตัวนับ REC เพิ่มขึ้น และตรวจไฟล์ checkpoint มี 10 ตัวอย่างขณะยังบันทึก
- รอบที่ตั้งไว้ 1 นาทีจบอัตโนมัติพร้อม endedAt: 57 ตัวอย่างในระยะเวลาจริงประมาณ 61 วินาที (ไม่ใช่การรับประกัน 1 Hz)
- ตรวจ JSON ที่บันทึกว่ามี timestamp เรียงลำดับและข้อมูลก่อน endedAt; archive reload/เปิดไฟล์ด้วย instance ใหม่ผ่าน automated integration check
- การเปรียบเทียบทางคณิตศาสตร์และ missing-data ผ่านชุดตรวจ; ยังไม่ได้ทดสอบเลือกสองรอบ/นำเข้า/ส่งออกครบทุก dialog ใน UI
- การบันทึกเมื่อปิดแอปตามปกติและการป้องกันปิดเมื่อ disk save ล้มเหลวมี implementation แล้ว แต่รอบนี้ไม่ได้ยืนยันกรณี disk-full/force-quit ผ่าน UI
- QA UI ถูกเปลี่ยนระหว่างการทดสอบ จึงไม่อ้างว่าการปิดแอป/เปิดใหม่สำเร็จจาก UI รอบนี้; หลักฐานรอบจริงที่ยืนยันได้คือ checkpoint และการจบตามเวลา


## รุ่น 1.5 — ผังช่องและความถี่

- Debug/release build และตรวจ codesign ผ่าน; Core checks ผ่าน 16 กลุ่ม
- เพิ่มตรวจรายการ primary/center แต่ละย่าน, ความกว้างที่ไม่รองรับ, สูตร MHz, CH 2 ของ 6 GHz, PSC 15 ช่อง และพิกัดตามความถี่ในฉาก 3D
- ตรวจภาพจริงผ่าน QA bundle แยก: การ์ด 2.4 GHz แสดง CH/MHz, AP และช่องเชื่อมต่อ พร้อมกราฟ RSSI จากข้อมูลจริง; เปลี่ยนเป็น 6 GHz แล้วเห็น CH 2 ก่อน CH 1 ตามความถี่ และป้าย PSC/การรองรับแยกชัดเจน
- macOS รายงานช่อง 6 GHz บางส่วน แต่ไม่พบ AP 6 GHz ใน snapshot นี้ จึงไม่ใช่การยืนยันการรับสัญญาณ 6 GHz/320 MHz จริง
- ข้อมูลประเทศไม่เปิดเผยแสดงเป็น “ไม่เปิดเผย”; ไม่เดาข้อกำหนด DFS หรืออนุญาตทุกช่องจากผังอ้างอิง
- เลือก Center 320 MHz ผ่าน UI แล้วแสดง 6 ตำแหน่ง center พร้อม MHz ถูกต้อง; เพิ่มระยะขอบแกน X เพื่อให้ป้ายช่องริมกราฟอ่านได้ครบ


## รุ่น 1.6 — ข้อมูลเครือข่ายในกราฟเชิงเส้น

- Debug/release build ผ่าน; regression core checks ผ่าน 16 กลุ่ม และ codesign strict verification ผ่าน
- ตรวจ QA app แยกด้วย CoreWLAN จริง: กราฟ RSSI เส้นทึบ / Noise เส้นประ สีฟ้า 2.4 GHz และป้าย CH 9 / 2452 MHz อัปเดตสด
- ตรวจและแก้ domain เวลาให้ตรงช่วงตัวอย่างจริง ไม่ใช้การปัดสเกลเลข Unix timestamp อัตโนมัติ
- QA ไม่มีสิทธิ์อ่าน SSID จึงยืนยัน fallback “ไม่เปิดเผย / ไม่ทราบ”; ไม่อ้างการทดสอบชื่อ SSID จริงหรือ roaming ข้ามย่านในรอบนี้
- ใช้ chart component เดียวกันกับ survey และ session ย้อนหลัง; ยังไม่ได้ทดสอบ UI ครบทุกชุดข้อมูลย้อนหลังและทุกขนาดหน้าต่าง
- การคลิกเลือกตัวอย่างย้อนหลังยังไม่ยืนยันผ่าน UI: Computer Use รายงาน noWindowsAvailable ระหว่างตรวจ; ไม่กระทบผล build หรือการแสดงกราฟสดที่ตรวจแล้ว
