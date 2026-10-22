class_name Icons
extends RefCounted
## Ícones pixel art 12x12 desenhados em texto (cada letra = uma cor). Para trocar, salve
## res://assets/ui/icons/<nome>.png com qualquer tamanho.

const PAL := {
	"k": Color("#1a1410"), "y": Color("#f6cf5a"), "Y": Color("#b8862a"), "w": Color("#ffffff"), "g": Color("#b4b0a8"),
	"G": Color("#6a6660"), "r": Color("#e8503a"), "R": Color("#8a2a20"), "b": Color("#5aa8ff"), "B": Color("#2a5a9a"),
	"n": Color("#6fd65a"), "N": Color("#2f8a2f"), "p": Color("#c07aff"), "P": Color("#6a2aa0"), "o": Color("#c08848"),
	"O": Color("#6a4420"), "c": Color("#8fe0f0"), "s": Color("#f0d8b0"), "m": Color("#ff8ac0"),
}

const DATA := {
	"coin": [
		"...kkkkkk...", "..kyyyyyyk..", ".kyywwyyyYk.", "kyywyyyyyyYk", "kyyyyYYyyyYk", "kyyyyYYyyyYk",
		"kyyyyYYyyyYk", "kyyyyyyyyyYk", "kYyyyyyyyYYk", ".kYYyyyyYYk.", "..kYYYYYYk..", "...kkkkkk...",
	],
	"gem": [
		"..kkkkkkkk..", ".kcwccccbbk.", "kcwcccccbbBk", "kkkkkkkkkkkk", ".kcwccccbBk.", ".kccwcccbBk.",
		"..kccccbBk..", "..kcccbbBk..", "...kccbBk...", "...kcbBk....", "....kbk.....", ".....k......",
	],
	"sword": [
		"..........kk", ".........kwk", "........kwgk", ".......kwgk.", "......kwgk..", ".k...kwgk...",
		".kk.kwgk....", "..kkogk.....", "..kOok......", ".kOkkk......", "kOk..kk.....", "kk..........",
	],
	"map": [
		"kkkkkkkkkkkk", "ksssksssksss", "ksrsksssksnk", "ksssrsssksnk", "kssskrssknnk", "ksssksrsksnk",
		"kssskssrksss", "ksssksssrsss", "ksbbksssksrk", "kbbbksssksss", "ksssksssksss", "kkkkkkkkkkkk",
	],
	"skull": [
		"...kkkkkk...", "..kwwwwwwk..", ".kwwwwwwwwk.", ".kwwwwwwwwk.", ".kwkkwwkkwk.", ".kwkkwwkkwk.",
		".kwwwwwwwwk.", "..kwwkkwwk..", "...kwwwwk...", "...kwkwkk...", "...kkkkk....", "............",
	],
	"paw": [
		"..kk....kk..", ".kook..kook.", ".kook..kook.", "..kk....kk..", "kk..kkkk..kk", "ookkoooookok",
		"kookoooooook", ".kkoooooookk", "..koooooook.", "..kooooooook", "...kkoookk..", ".....kkk....",
	],
	"chest": [
		"..kkkkkkkk..", ".kooooooook.", "kOooooooooOk", "kkkkkkkkkkkk", "kOookyykooOk", "koookyykoook",
		"koookkkkoook", "kooooooooook", "kOooooooooOk", "kOOOOOOOOOOk", "kkkkkkkkkkkk", "............",
	],
	"bag": [
		"....kkkk....", "...kokkok...", "...kk..kk...", "..kkkkkkkk..", ".koooooooook", "kooooyyoooOk",
		"koooyyyyoooO", "kooooyyooooO", "kooooooooooO", "kOooooooooOk", ".kOOOOOOOOk.", "..kkkkkkkk..",
	],
	"shop": [
		"kkkkkkkkkkkk", "krwrwrwrwrwk", "krwrwrwrwrwk", "kkkkkkkkkkkk", ".koooooooook", ".kokkkoskkok",
		".kokwkoskwok", ".kokkkoskkok", ".koooooooook", ".kokkoooooOk", ".kOkkoooooOk", ".kkkkkkkkkkk",
	],
	"scales": [
		".....kk.....", ".....yy.....", "kkkkkyykkkkk", "k.y..yy..y.k", "k.y..yy..y.k", "ky.y.yy.y.yk",
		"yyyy.yy.yyyy", ".yy..yy..yy.", ".....yy.....", "....kyyk....", "...kyyyyk...", "..kkkkkkkk..",
	],
	"altar": [
		".....kk.....", "....kppk....", "...kpwppk...", "...kpppPk...", "....kPPk....", ".....kk.....",
		"..kkkkkkkk..", "..kggggggk..", "...kgGGgk...", "...kgGGgk...", "..kggggggk..", ".kkkkkkkkkk.",
	],
	"book": [
		".kkkkkkkkkk.", "kbbbbbbbbbBk", "kbwwwwwwwwBk", "kbwkkkkkwwBk", "kbwwwwwwwwBk", "kbwkkkkwwwBk",
		"kbwwwwwwwwBk", "kbwkkkkkkwBk", "kbwwwwwwwwBk", "kbbbbbbbbbBk", "kBBBBBBBBBBk", ".kkkkkkkkkk.",
	],
	"trophy": [
		"kkkkkkkkkkkk", "kyyyyyyyyyyk", "kyywyyyyyyYk", ".kywyyyyyYk.", ".kyyyyyyyYk.", "..kyyyyyYk..",
		"...kyyyYk...", "....kyYk....", "....kYYk....", "...kyyyYk...", "..kYYYYYYk..", "..kkkkkkkk..",
	],
	"gear": [
		"....kkkk....", ".kk.kggk.kk.", ".kgkkggkkgk.", "..kgggggGk..", "kkkgGkkGgkkk", "kgggk..kgggk",
		"kgggk..kgGGk", "kkkgGkkGgkkk", "..kgGGGGGk..", ".kgkkGGkkGk.", ".kk.kGGk.kk.", "....kkkk....",
	],
	"star": [
		".....kk.....", ".....yk.....", "....kyyk....", "....kyyk....", "kkkkyyyykkkk", "kyyyywyyyyYk",
		".kyyyyyyyYk.", "..kyyyyyYk..", "..kyyYyyYk..", ".kyyYkkYyYk.", ".kYYk..kYYk.", ".kk......kk.",
	],
	"star_empty": [
		".....kk.....", ".....Gk.....", "....kGGk....", "....kG.k....", "kkkkG..Gkkkk", "kG........Gk",
		".kG......Gk.", "..kG....Gk..", "..kG.GG.Gk..", ".kG.kkk.Gk..", ".kGk..kGGk..", ".kk......kk.",
	],
	"lock": [
		"....kkkk....", "...kgggGk...", "..kgk..kGk..", "..kgk..kGk..", "..kgk..kGk..", ".kkkkkkkkkk.",
		".kyyyyyyyYk.", ".kyyykkyyYk.", ".kyyykkyyYk.", ".kyyyyyyyYk.", ".kYYYYYYYYk.", ".kkkkkkkkkk.",
	],
	"play": [
		"..kk........", "..kwkk......", "..kwwwkk....", "..kwwwwwkk..", "..kwwwwwwwk.", "..kwwwwwwwwk",
		"..kwwwwwwwwk", "..kwwwwwwwk.", "..kwwwwwkk..", "..kwwwkk....", "..kwkk......", "..kk........",
	],
	"crown": [
		"............", "k....kk....k", "kk..kyyk..kk", "kyk.kyyk.kyk", "kyykyyyykyyk", "kyyyyryyyyyk",
		"kyyyrrryyyyk", "kyyyyryyyyYk", "kYYYYYYYYYYk", "kkkkkkkkkkkk", "kYyYyYyYyYYk", "kkkkkkkkkkkk",
	],
	"clock": [
		"...kkkkkk...", "..kwwwwwwk..", ".kwwwkwwwwk.", "kwwwwkwwwwwk", "kwwwwkwwwwwk", "kwwwwkkkkwwk",
		"kwwwwwwwwwwk", "kwwwwwwwwwwk", ".kwwwwwwwwk.", "..kwwwwwwk..", "...kkkkkk...", "............",
	],
	"back": [
		"............", ".....kk.....", "....kwk.....", "...kwwkkkkk.", "..kwwwwwwwwk", ".kwwwwwwwwwk",
		"..kwwwwwwwwk", "...kwwkkkkk.", "....kwk.....", ".....kk.....", "............", "............",
	],
	"heart": [
		"............", ".kkk...kkk..", "krrrk.krrrk.", "krwrrkrrrrRk", "krrrrrrrrrRk", "krrrrrrrrrRk",
		".krrrrrrrRk.", "..krrrrrRk..", "...krrrRk...", "....krRk....", ".....kk.....", "............",
	],
	"plus": [
		"............", "....kkkk....", "....kwwk....", "....kwwk....", "kkkkkwwkkkkk", "kwwwwwwwwwwk",
		"kwwwwwwwwwwk", "kkkkkwwkkkkk", "....kwwk....", "....kwwk....", "....kkkk....", "............",
	],
	"minus": [
		"............", "............", "............", "............", "kkkkkkkkkkkk", "kwwwwwwwwwwk",
		"kwwwwwwwwwwk", "kkkkkkkkkkkk", "............", "............", "............", "............",
	],
	"check": [
		"............", "..........kk", ".........knk", "........knk.", ".kk....knk..", "knnk..knk...",
		".knnkknk....", "..knnnk.....", "...knk......", "....k.......", "............", "............",
	],
	"cross": [
		"............", ".kk......kk.", "krrk....krrk", ".krrk..krrk.", "..krrkkrrk..", "...krrrrk...",
		"...krrrrk...", "..krrkkrrk..", ".krrk..krrk.", "krrk....krrk", ".kk......kk.", "............",
	],
	"globe": [
		"...kkkkkk...", "..kbbnnbbk..", ".kbnnnnbbbk.", "kbbnnnbbbbbk", "kbbbnnbbnnbk", "kbbbbbbnnnbk",
		"kbbbbbbnnnbk", "kbnnbbbbnbbk", ".kbnnbbbbbk.", "..kbbbbbbk..", "...kkkkkk...", "............",
	],
	"cloud": [
		"............", "....kkkk....", "...kwwwwk...", ".kkwwwwwwk..", "kwwwwwwwwwk.", "kwwwwwwwwwwk",
		"kgwwwwwwwwgk", ".kgggggggk..", "..kkkkkkk...", "............", "............", "............",
	],
	"user": [
		"....kkkk....", "...ksssk....", "..kssssskk..", "..kskskssk..", "..ksssssk...", "...kssskk...",
		"..kkkkkkkk..", ".kbbbbbbbbk.", "kbbbbbbbbbbk", "kbbbbbbbbbbk", "kbbbbbbbbbbk", "kkkkkkkkkkkk",
	],
	"flame": [
		".....k......", "....kyk.....", "....kyyk....", "...kyyyrk...", "..kyyyyrrk..", "..kyywyyrk..",
		".kryyyyyyrk.", ".kryywyyyrk.", ".krryyyyrrk.", "..krrrrrrk..", "...kkkkkk...", "............",
	],
	"house": [
		".....kk.....", "....krrk....", "...krrrrk...", "..krrrrrrk..", ".krrrrrrrrk.", "kkkkkkkkkkkk",
		".kooooooook.", ".kowwkkoook.", ".kowwkokook.", ".kooookokok.", ".kooookokok.", ".kkkkkkkkkk.",
	],
	"egg": [
		"....kkkk....", "...kwwwwk...", "..kwwwwwwk..", "..kwwnwwwk..", ".kwwnnwwwwk.", ".kwwwwwbwwk.",
		".kwwwwbbwwk.", ".kwnwwwwwgk.", ".kwnnwwwwgk.", "..kwwwwwgk..", "...kkkkkk...", "............",
	],
	"bolt": [
		"......kkk...", ".....kyyk...", "....kyyk....", "...kyyk.....", "..kyyykkk...", "..kyyyyyyk..",
		"...kkkyyk...", ".....kyk....", "....kyk.....", "....kk......", "...kk.......", "............",
	],
	"sparkle": [
		".....k......", ".....y......", ".....y......", "....kyk.....", "kyyyywyyyyk.", "....kyk.....",
		".....y......", ".....y....k.", ".....k...kyk", ".........kyk", "..........k.", "............",
	],
}

static var _cache := {}


static func tex(name: String) -> Texture2D:
	if _cache.has(name):
		return _cache[name]
	var path := "res://assets/ui/icons/%s.png" % name
	var t: Texture2D
	if ResourceLoader.exists(path):
		t = load(path)
	else:
		t = ImageTexture.create_from_image(image(name))
	_cache[name] = t
	return t


static func image(name: String) -> Image:
	var rows: Array = DATA.get(name, DATA["star"])
	var img := Image.create(12, 12, false, Image.FORMAT_RGBA8)
	for y in rows.size():
		var row: String = rows[y]
		for x in mini(12, row.length()):
			var ch := row[x]
			if PAL.has(ch):
				img.set_pixel(x, y, PAL[ch])
	return img
