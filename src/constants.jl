const CHARACTERS = ['P', 'N', 'B', 'R', 'Q', 'K', '⚠', '⚠', 'p', 'n', 'b', 'r', 'q', 'k', '⚠', '⚠']

const WHITE = 0b0000
const BLACK = 0b1000

const EMPTY = 0
const NO_PIECE = 0
const NO_SQUARE = 0x00

const PAWN = 0b0001
const KNIGHT = 0b0010
const BISHOP = 0b0011
const ROOK = 0b0100
const QUEEN = 0b0101
const KING = 0b0110

const WHITE_PAWN = PAWN | WHITE
const WHITE_KNIGHT = KNIGHT | WHITE
const WHITE_BISHOP = BISHOP | WHITE
const WHITE_ROOK = ROOK | WHITE
const WHITE_QUEEN = QUEEN | WHITE
const WHITE_KING = KING | WHITE

const BLACK_PAWN = PAWN | BLACK
const BLACK_KNIGHT = KNIGHT | BLACK
const BLACK_BISHOP = BISHOP | BLACK
const BLACK_ROOK = ROOK | BLACK
const BLACK_QUEEN = QUEEN | BLACK
const BLACK_KING = KING | BLACK

const CASTLING_WK = 0b0001
const CASTLING_WQ = 0b0010
const CASTLING_BK = 0b0100
const CASTLING_BQ = 0b1000
const NO_CASTLING = 0b0000
const CASTLING_W = 0b0011
const CASTLING_B = 0b1100

const CLEAR_FILE_A = 0xFEFEFEFEFEFEFEFE
const CLEAR_FILE_B = 0xFDFDFDFDFDFDFDFD
const CLEAR_FILE_G = 0xBFBFBFBFBFBFBFBF
const CLEAR_FILE_H = 0x7F7F7F7F7F7F7F7F
const CLEAR_RANK_1 = 0xFFFFFFFFFFFFFF00
const CLEAR_RANK_8 = 0x00FFFFFFFFFFFFFF
const RANK_1 = 0x00000000000000FF
const RANK_2 = 0x000000000000FF00
const RANK_3 = 0x0000000000FF0000
const RANK_4 = 0x00000000FF000000
const RANK_5 = 0x000000FF00000000
const RANK_6 = 0x0000FF0000000000
const RANK_7 = 0x00FF000000000000
const RANK_8 = 0xFF00000000000000

const QUIET = 0x00
const DOUBLE_PAWN_PUSH = 0x01
const KING_CASTLE = 0x02
const QUEEN_CASTLE = 0x03
const CAPTURE = 0x04
const EN_PASSANT = 0x05
const KNIGHT_PROMOTION = 0x08
const BISHOP_PROMOTION = 0x09
const ROOK_PROMOTION = 0x0A
const QUEEN_PROMOTION = 0x0B
const KNIGHT_PROMOTION_CAPTURE = 0x0C
const BISHOP_PROMOTION_CAPTURE = 0x0D
const ROOK_PROMOTION_CAPTURE = 0x0E
const QUEEN_PROMOTION_CAPTURE = 0x0F
const PROMOTION = 0x08
