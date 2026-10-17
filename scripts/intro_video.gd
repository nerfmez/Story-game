class_name IntroVideo
extends Node
## วิดีโอเปิดเรื่อง (ซันที่บ้าน: ฝนตก กินขนม หยิบกระเป๋า หยิบร่ม เปิดประตู) เล่นทันทีหลังแตะเพื่อเริ่ม
## บนเว็บเล่นด้วยแท็ก <video> ของเบราว์เซอร์ทับบนเกม (ถอดรหัส H.264 ด้วยฮาร์ดแวร์ ภาพคมเต็มจอ)
## ไฟล์อยู่ข้าง index.html (ต้นฉบับ: web/intro.mp4) โหลดล่วงหน้าตั้งแต่ตอนคำโปรย
## เบราว์เซอร์มือถือ (โดยเฉพาะ iOS) ยอมเล่นวิดีโอมีเสียงเฉพาะในจังหวะที่ผู้เล่นแตะ: arm() ตอนขึ้น "แตะเพื่อเริ่ม"
## แล้วการแตะครั้งนั้นสั่งเล่นวิดีโอทันทีจากฝั่ง JavaScript
## นอกเว็บ (เปิดในเอดิเตอร์/เดสก์ท็อป) ข้ามวิดีโอไป

signal finished

@export var url := "intro.mp4"

var _web := OS.has_feature("web")


func _ready() -> void:
	if not _web:
		return
	JavaScriptBridge.eval("""
(function () {
	if (window.introVideo) { window.introVideo.reset(); return; }
	var v = document.createElement('video');
	v.src = '%s';
	v.preload = 'auto';
	v.playsInline = true;
	v.setAttribute('playsinline', '');
	v.setAttribute('webkit-playsinline', '');
	v.style.cssText = 'position:fixed;inset:0;width:100%%;height:100%%;object-fit:contain;background:#000;'
		+ 'z-index:1000;opacity:0;transition:opacity 0.6s;pointer-events:none;display:none;';
	document.body.appendChild(v);
	var iv = { video: v, armed: false, state: 'idle' };
	iv.reset = function () { iv.armed = false; iv.state = 'idle'; v.pause(); v.currentTime = 0; v.style.display = 'none'; v.style.opacity = 0; };
	iv.start = function () {
		if (iv.state !== 'idle') return;
		iv.state = 'playing';
		v.style.display = 'block';
		requestAnimationFrame(function () { v.style.opacity = 1; });
		var p = v.play();
		if (p && p.catch) p.catch(function () { iv.state = 'failed'; });
	};
	iv.finish = function () {
		v.style.opacity = 0;
		setTimeout(function () { v.style.display = 'none'; iv.state = 'ended'; }, 650);
	};
	v.addEventListener('ended', iv.finish);
	v.addEventListener('error', function () { if (iv.state === 'playing') iv.state = 'failed'; });
	var tap = function () { if (iv.armed) { iv.armed = false; iv.start(); } };
	['touchend', 'pointerup', 'mouseup', 'keydown'].forEach(function (e) { document.addEventListener(e, tap, true); });
	window.introVideo = iv;
})();
""" % url)


## ให้การแตะครั้งถัดไปเริ่มวิดีโอ (เรียกตอนขึ้น "แตะเพื่อเริ่ม")
func arm() -> void:
	if _web:
		JavaScriptBridge.eval("window.introVideo && (window.introVideo.armed = true);")


## เล่นจนจบ (ถ้าการแตะยังไม่ได้เริ่มให้ ก็สั่งเล่นจากตรงนี้) เล่นไม่ได้ก็ข้ามไป
func play() -> void:
	if not _web:
		return
	JavaScriptBridge.eval("window.introVideo && window.introVideo.start();")
	while true:
		var state = JavaScriptBridge.eval("window.introVideo ? window.introVideo.state : 'failed'")
		if state == "ended" or state == "failed":
			break
		await get_tree().process_frame
	JavaScriptBridge.eval("window.introVideo && (window.introVideo.state === 'failed') && window.introVideo.reset();")
	finished.emit()
