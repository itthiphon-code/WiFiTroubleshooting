# Channel plan provenance — 2026-10-03

ข้อมูลใน `Sources/WiFiCore/ChannelPlan.swift` เป็นผังอ้างอิง WLAN ไม่ใช่รายการอนุญาตตามกฎหมายของประเทศใดประเทศหนึ่ง และไม่ใช้ตั้งช่อง router โดยอัตโนมัติ

| ส่วนข้อมูล | วิธีระบุ |
|---|---|
| 2.4 GHz primary | CH 1–13: 2407 + 5 × CH MHz; CH 14: 2484 MHz (legacy 802.11b จำกัดตามประเทศ) |
| 5 GHz primary ที่อยู่ในผังนี้ | 36–64, 100–144, 149–177 ขั้นละ 4; 5000 + 5 × CH MHz |
| 6 GHz primary | 1–233 ขั้นละ 4; 5950 + 5 × CH MHz; CH 2 พิเศษที่ 5935 MHz |
| Center channel | เลือกตาม bandwidth แยกจาก primary; ตาราง 40/80/160/320 MHz ไม่ใช่การยืนยันความกว้างที่ adapter รองรับ |
| PSC | เฉพาะ 6 GHz: CH 5 + 16n, n = 0…14 |
| สถานะจากฮาร์ดแวร์ | `supportedWLANChannels()` ของ CoreWLAN สำหรับ country code ปัจจุบัน; nil คือไม่มีข้อมูล ไม่ถือว่าไม่รองรับทั้งหมด |

แหล่งตรวจสอบ:

1. [MathWorks WLAN Toolbox — Valid Channel Number and Bandwidth Combinations](https://www.mathworks.com/help/wlan/ug/valid-channel-number-and-bandwidth-combinations.html): primary/center และผัง 5/6 GHz รวม 320 MHz อ้าง IEEE 802.11-2020, 802.11ax-2021 และ P802.11be D7.0 Annex E ตารางนี้ไม่ใช่ regulatory authorization
2. [Linux wireless util.c](https://github.com/torvalds/linux/blob/master/net/wireless/util.c): `ieee80211_channel_to_freq_khz`, operating classes 81/82/83/84/115/118/121/124/125/131/136 และ primary→center offset. สำหรับ 2.4 GHz 40 MHz ใช้ class 83 primary 1…9 บวก 10 MHz หรือ class 84 primary 5…13 ลบ 10 MHz จึงได้ center CH 3…11 (ไม่จำกัดตามชุดจำลองของ MathWorks ที่แสดงถึง CH 10)
3. [Linux cfg80211.h](https://github.com/torvalds/linux/blob/master/include/net/cfg80211.h): `cfg80211_channel_is_psc` สำหรับ PSC 6 GHz
4. [Cisco Wireless RF Reference Guide](https://www.cisco.com/c/en/us/td/docs/wireless/controller/9800/technical-reference/wireless-rf-reference-guide.html): ผัง/การซ้อนทับ 2.4 GHz และจำนวนช่องปกติของ 6 GHz
5. [Apple CoreWLAN supportedWLANChannels](https://developer.apple.com/documentation/corewlan/cwinterface/supportedwlanchannels()): ช่องที่ adapter รองรับ ตรวจคำอธิบาย country code และ nil จาก CWInterface.h ใน macOS SDK บนเครื่องด้วย

ข้อจำกัดการแสดงผล:

- 6 GHz ปกติมี 59 primary channels; CH 2 เป็นกรณีพิเศษแสดงแยกเป็นลำดับแรกตามความถี่ จึงมี 60 ช่องใน reference selector เมื่อรวมกรณีพิเศษ
- CH 14 รวมในตัวเลือก primary เพื่อไม่ซ่อน legacy channel แต่ไม่แสดงช่วง OFDM 20 MHz ให้เข้าใจผิด แสดงหมายเหตุ 802.11b/22 MHz แทน
- 320 MHz มี center placements หกตำแหน่งที่ซ้อนทับกัน ไม่ใช่หกช่อง non-overlapping
- ช่วง MHz บนผัง center ± bandwidth/2 เป็น nominal allocation ไม่ใช่ spectral mask หรือการตรวจวัด spectrum
- ช่องที่ไม่ปรากฏในผังทั่วไป เช่น regional/4.9 GHz ยังคงปรากฏในตารางเครือข่ายตามค่าที่ API รายงาน; ไม่วางแท่ง 3D ไว้ในแกนปกติอย่างผิดตำแหน่ง
- แกน 3D แต่ละย่านมีสเกล MHz ของตัวเอง ระยะห่างข้ามแถวไม่ใช่ระยะทางทางกายภาพหรือสเกลความถี่ร่วม
- ไม่เดา DFS permission หรืออนุมาน center ของ AP ที่ใช้ช่องกว้างจาก primary/width เพียงอย่างเดียว
