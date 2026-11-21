extends Object
class_name FormatUtil

static func num(n: float, decimals: int = 2) -> String:
	if is_nan(n) or is_inf(n):
		return "–"
	return String.num(n, decimals)
