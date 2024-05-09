# module LookUp

struct MagicTable
    mask::Vector{UInt64}
    magic::Vector{UInt64}
    shift::Vector{UInt64}
    attack_table::Matrix{UInt64}
end

struct LookUpTables
    rook_table::MagicTable
    bishop_table::MagicTable
    king_table::Vector{UInt64}
    knight_table::Vector{UInt64}
    between_table::Matrix{UInt64}
    line_spanned_table::Matrix{UInt64}
    square_table::Vector{UInt64}
end

function generate_square_table()
    table = zeros(UInt64, 64)
    for i in 0:63
        table[i + 1] = UInt64(1) << i
    end
    return table
end

function generate_between_table()
    table = zeros(UInt64, 64, 64)
    for i in 0:63
        for j in 0:63
            if i != j 
                sq1, sq2 = sort(i, j)
                if rank(sq1) == rank(sq2)
                    for i in sq1+1:sq2-1
                        table[sq1 + 1, sq2 + 1] |= UInt64(1) << i
                        table[sq2 + 1, sq1 + 1] |= UInt64(1) << i
                    end
                elseif file(sq1) == file(sq2)
                    for i in sq1+8:8:sq2-8
                        table[sq1 + 1, sq2 + 1] |= UInt64(1) << i
                        table[sq2 + 1, sq1 + 1] |= UInt64(1) << i
                    end
                elseif diagonal(sq1) == diagonal(sq2)
                    for i in sq1+9:9:sq2-9
                        table[sq1 + 1, sq2 + 1] |= UInt64(1) << i
                        table[sq2 + 1, sq1 + 1] |= UInt64(1) << i
                    end
                elseif anti_diagonal(sq1) == anti_diagonal(sq2)
                    for i in sq1+7:7:sq2-7
                        table[sq1 + 1, sq2 + 1] |= UInt64(1) << i
                        table[sq2 + 1, sq1 + 1] |= UInt64(1) << i
                    end
                end
            end
        end
    end
    return table
end

function generate_line_spanned_table()
    table = zeros(UInt64, 64, 64)
    for i in 0:63
        for j in 0:63
            if i != j 
                sq1, sq2 = sort(i, j)
                if rank(sq1) == rank(sq2)
                    for i in rank(sq1)*8:rank(sq1)*8+7
                        table[sq1 + 1, sq2 + 1] |= UInt64(1) << i
                        table[sq2 + 1, sq1 + 1] |= UInt64(1) << i
                    end
                elseif file(sq1) == file(sq2)
                    for i in file(sq1):8:56+file(sq1)
                        table[sq1 + 1, sq2 + 1] |= UInt64(1) << i
                        table[sq2 + 1, sq1 + 1] |= UInt64(1) << i
                    end
                elseif diagonal(sq1) == diagonal(sq2)
                    start_idx = diagonal(sq1) < 8 ? 7 - diagonal(sq1) : 8 * (diagonal(sq1) - 7)
                    end_idx = diagonal(sq1) < 8 ? diagonal(sq1) * 8 + 7 : 70 - diagonal(sq1)
                    for i in start_idx:9:end_idx
                        table[sq1 + 1, sq2 + 1] |= UInt64(1) << i
                        table[sq2 + 1, sq1 + 1] |= UInt64(1) << i
                    end
                elseif anti_diagonal(sq1) == anti_diagonal(sq2)
                    start_idx = anti_diagonal(sq1) < 8 ? anti_diagonal(sq1) : 8 * (anti_diagonal(sq1) - 7) + 7
                    end_idx = anti_diagonal(sq1) < 8 ? anti_diagonal(sq1) * 8 : 49 + anti_diagonal(sq1)
                    for i in start_idx:7:end_idx
                        table[sq1 + 1, sq2 + 1] |= UInt64(1) << i
                        table[sq2 + 1, sq1 + 1] |= UInt64(1) << i
                    end
                end
            end
        end
    end
    return table
end

function generate_knight_table()
    table = zeros(UInt64, 64)

    for i in 0:63
        knight = UInt64(1) << i

        attacks = ((knight & CLEAR_FILE_A & CLEAR_FILE_B) << 6) |
                    ((knight & CLEAR_FILE_A & CLEAR_FILE_B) >> 10)  |
                    ((knight & CLEAR_FILE_G & CLEAR_FILE_H) << 10) |
                    ((knight & CLEAR_FILE_G & CLEAR_FILE_H) >> 6)  |
                    ((knight & CLEAR_FILE_A) << 15) |
                    ((knight & CLEAR_FILE_H) << 17) |
                    ((knight & CLEAR_FILE_A) >> 17) |
                    ((knight & CLEAR_FILE_H) >> 15)
        
        table[i + 1] = attacks
    end

    return table
end

function generate_king_table()
    table = zeros(UInt64, 64)

    for i in 0:63
        king = UInt64(1) << i

        attacks =  ((king & CLEAR_FILE_A) >> 1) | 
                    ((king & CLEAR_FILE_A) << 7) |
                    ((king & CLEAR_FILE_A) >> 9) |
                    ((king & CLEAR_FILE_H) << 1) |
                    ((king & CLEAR_FILE_H) << 9) |
                    ((king & CLEAR_FILE_H) >> 7) |
                    (king >> 8) |
                    (king << 8)

        
        table[i + 1] = attacks
    end

    return table
end

function generate_rook_mask_table()
    table = zeros(UInt64, 64)

    for i in 0:63
        mask = 0x0000000000000000

        # north
        sq = i
        while rank(sq) < 6
            sq += 8
            mask |= UInt64(1) << sq
        end

        # south
        sq = i
        while rank(sq) > 1
            sq -= 8
            mask |= UInt64(1) << sq
        end

        # east
        sq = i
        while file(sq) < 6
            sq += 1
            mask |= UInt64(1) << sq
        end

        # west
        sq = i
        while file(sq) > 1
            sq -= 1
            mask |= UInt64(1) << sq
        end
        table[i + 1] = mask
    end

    return table
end

function generate_bishop_mask_table()
    table = zeros(UInt64, 64)

    for i in 0:63
        mask = 0x0000000000000000

        # north-east
        sq = i
        while rank(sq) < 6 && file(sq) < 6
            sq += 9
            mask |= UInt64(1) << sq
        end

        # south-east
        sq = i
        while rank(sq) > 1 && file(sq) < 6
            sq -= 7
            mask |= UInt64(1) << sq
        end

        # south-west
        sq = i
        while rank(sq) > 1 && file(sq) > 1
            sq -= 9
            mask |= UInt64(1) << sq
        end

        # north-west
        sq = i
        while rank(sq) < 6 && file(sq) > 1
            sq += 7
            mask |= UInt64(1) << sq
        end
        table[i + 1] = mask
    end

    return table
end

function compute_rook_attack(square, blockers::UInt64)
    attacks = 0x0000000000000000

    # north
    sq = square
    while rank(sq) < 7
        sq += 8
        attacks |= UInt64(1) << sq
        if blockers & (UInt64(1) << sq) != 0
            break
        end
    end

    # south
    sq = square
    while rank(sq) > 0
        sq -= 8
        attacks |= UInt64(1) << sq
        if blockers & (UInt64(1) << sq) != 0
            break
        end
    end

    # east
    sq = square
    while file(sq) < 7
        sq += 1
        attacks |= UInt64(1) << sq
        if blockers & (UInt64(1) << sq) != 0
            break
        end
    end

    # west
    sq = square
    while file(sq) > 0
        sq -= 1
        attacks |= UInt64(1) << sq
        if blockers & (UInt64(1) << sq) != 0
            break
        end
    end

    return attacks
end

function compute_bishop_attack(square, blockers::UInt64)
    attacks = 0x0000000000000000

    # north-east
    sq = square
    while rank(sq) < 7 && file(sq) < 7
        sq += 9
        attacks |= UInt64(1) << sq
        if blockers & (UInt64(1) << sq) != 0
            break
        end
    end

    # south-east
    sq = square
    while rank(sq) > 0 && file(sq) < 7
        sq -= 7
        attacks |= UInt64(1) << sq
        if blockers & (UInt64(1) << sq) != 0
            break
        end
    end

    # south-west
    sq = square
    while rank(sq) > 0 && file(sq) > 0
        sq -= 9
        attacks |= UInt64(1) << sq
        if blockers & (UInt64(1) << sq) != 0
            break
        end
    end

    # north-west
    sq = square
    while rank(sq) < 7 && file(sq) > 0
        sq += 7
        attacks |= UInt64(1) << sq
        if blockers & (UInt64(1) << sq) != 0
            break
        end
    end

    return attacks
end

function index_to_blocker_pattern(idx, possible_blockers::UInt64, nr_of_possible_blockers::UInt64)
    blocker_pattern = 0x0000000000000000
    for i in 0:nr_of_possible_blockers - 1
        ith_blocker = trailing_zeros(possible_blockers)
        possible_blockers &= possible_blockers - 1
        if idx & (1 << i) != 0
            blocker_pattern |= UInt64(1) << ith_blocker
        end
    end
    return blocker_pattern
end

# for every square we have to compute all possible blocker masks
    # and for every blocker mask, map it to an index in the attack table (where the precomputed attacks are stored)
    #
    # the idea is best explained for a concrete example:
    #
    # sq = b3 
    # 
    # possible blocker fields = 
    #
    #       0 0 0 0 0 0 0 0 
    #       0 1 0 0 0 0 0 0 
    #       0 1 0 0 0 0 0 0 
    #       0 1 0 0 0 0 0 0 
    #       0 1 0 0 0 0 0 0 
    #       0 x 1 1 1 1 1 0 
    #       0 1 0 0 0 0 0 0 
    #       0 0 0 0 0 0 0 0
    #
    # there are atmost 10 blockers for a rook on b3 (since outermost squares are not relevant for blockers)
    # hence => 2^10 = 1024 possible blocker masks
    #
    # now we iterate through all possible indices 0 , 1, 2, 3, ... 1023
    # or in binary 0000000000, 0000000001, 0000000010, 0000000011, ...
    #
    # now we map every index in such a way, that if the i'th bit is set in the index
    # then the i'th 1-bit of the possible blockers mask is set (of the 10 possible 1-bits for b3) 
    #
    # for the index (msb) 0001000010 (lsb)
    # the corresponding blocker mask would be 
    #
    #       0 0 0 0 0 0 0 0      0 0 0 0 0 0 0 0    56 57 58 59 60 61 62 63 
    #       0 1 0 0 0 0 0 0      0 0 0 0 0 0 0 0    48 49 50 51 52 53 54 55
    #       0 1 0 0 0 0 0 0      0 0 0 0 0 0 0 0    40 41 42 43 44 45 46 47 
    #       0 1 0 0 0 0 0 0  =>  0 0 0 0 0 0 0 0    32 33 34 35 36 37 38 39 
    #       0 1 0 0 0 0 0 0  =>  0 1 0 0 0 0 0 0    24 25 26 27 28 29 30 31
    #       0 x 1 1 1 1 1 0      0 x 0 0 0 0 1 0    16 17 18 19 20 21 22 23
    #       0 1 0 0 0 0 0 0      0 0 0 0 0 0 0 0    8  9  10 11 12 13 14 15
    #       0 0 0 0 0 0 0 0      0 0 0 0 0 0 0 0    0  1   2  3  4  5  6  7
    #
    # since computing the index given a blocker mask is a very expensive operation
    # - i.e. we would have to reverse the mapping function described above - 
    # we use a different approach: magic bitboards
    #
    # the idea is to precompute a magic number for every square, for which following is true:
    # - for a specific square, for every possible blocker mask (where at most n bits of the possible 64-bits are set),
    #   the blocker_mask * magic collapses onto the upper n bits, i.e.
    #   (blocker_mask * magic) >> (64 - n) is a valid index into the attack table
    #
    # in summary (pseudo code)
    # for sq in all_squares:
    #   n = number_of_possible_blockers(sq)
    #   for i in 0, 1, 2, 3, ... 2^n - 1:
    #       blocker_mask = index_to_blocker_mask(i)
    #       idx = (blocker_mask * magic[sq]) >> (64 - n)
    #       attack_table[sq][idx] = compute_attack(sq, blocker_mask)
    #

function generate_rook_table()
    magic_table = Vector{UInt64}([
            0xa8002c000108020,
            0x4440200140003000,
            0x8080200010011880,
            0x380180080141000,
            0x1a00060008211044,
            0x410001000a0c0008,
            0x9500060004008100,
            0x100024284a20700,
            0x802140008000,
            0x80c01002a00840,
            0x402004282011020,
            0x9862000820420050,
            0x1001448011100,
            0x6432800200800400,
            0x40100010002000c,
            0x2800d0010c080,
            0x90c0008000803042,
            0x4010004000200041,
            0x3010010200040,
            0xa40828028001000,
            0x123010008000430,
            0x24008004020080,
            0x60040001104802,
            0x582200028400d1,
            0x4000802080044000,
            0x408208200420308,
            0x610038080102000,
            0x3601000900100020,
            0x80080040180,
            0xc2020080040080,
            0x80084400100102,
            0x4022408200014401,
            0x40052040800082,
            0xb08200280804000,
            0x8a80a008801000,
            0x4000480080801000,
            0x911808800801401,
            0x822a003002001894,
            0x401068091400108a,
            0x4a10a00004c,
            0x2000800640008024,
            0x1486408102020020,
            0x100a000d50041,
            0x810050020b0020,
            0x204000800808004,
            0x20048100a000c,
            0x112000831020004,
            0x9000040810002,
            0x440490200208200,
            0x8910401000200040,
            0x6404200050008480,
            0x4b824a2010010100,
            0x4080801810c0080,
            0x400802a0080,
            0x8224080110026400,
            0x40002c4104088200,
            0x1002100104a0282,
            0x1208400811048021,
            0x3201014a40d02001,
            0x5100019200501,
            0x101000208001005,
            0x2008450080702,
            0x1002080301d00c,
            0x410201ce5c030092
        ])

    shift_table = Vector{UInt64}([
        52, 53, 53, 53, 53, 53, 53, 52,
        53, 54, 54, 54, 54, 54, 54, 53,
        53, 54, 54, 54, 54, 54, 54, 53,
        53, 54, 54, 54, 54, 54, 54, 53,
        53, 54, 54, 54, 54, 54, 54, 53,
        53, 54, 54, 54, 54, 54, 54, 53,
        53, 54, 54, 54, 54, 54, 54, 53,
        52, 53, 53, 53, 53, 53, 53, 52
    ])
    possible_blockers_table = generate_rook_mask_table()
    attack_table = zeros(UInt64, 64, 4096)


    for sq in 0:63
        possible_blockers = possible_blockers_table[sq + 1]
        nr_of_possible_blockers = 64 - shift_table[sq+1]
        
        for idx in 0:2^nr_of_possible_blockers - 1
            blocker_pattern = index_to_blocker_pattern(idx, possible_blockers, nr_of_possible_blockers)
            blocker_index= (blocker_pattern * magic_table[sq+1]) >> shift_table[sq+1]
            attack_table[sq+1, blocker_index + 1] = compute_rook_attack(sq, blocker_pattern)
        end
    end

    # EXAMPLE ITERATION for 18th iteration (sq = b3 = 17)
    # for sq(b3=17) in 0:63 ...
        # possible_blockers for sq = b3 = 17 is:
        # possible_blockers =
        #       0 0 0 0 0 0 0 0 
        #       0 1 0 0 0 0 0 0 
        #       0 1 0 0 0 0 0 0 
        #       0 1 0 0 0 0 0 0 
        #       0 1 0 0 0 0 0 0 
        #       0 x 1 1 1 1 1 0 
        #       0 1 0 0 0 0 0 0 
        #       0 0 0 0 0 0 0 0
        # number_of_possible_blockers = 10
        #
        # example iteration for idx = 0b0001000010
        # for idx(0b0001000010) in 0, 1, 2, 3, ... 1023
            # blocker_pattern for idx = 0b0001000010 is:
            # blocker_pattern = 0x0000000002400000 = 
            #       0 0 0 0 0 0 0 0    
            #       0 0 0 0 0 0 0 0     
            #       0 0 0 0 0 0 0 0     
            #       0 1 0 0 0 0 0 0    
            #       0 x 0 0 0 0 1 0    
            #       0 0 0 0 0 0 0 0    
            #       0 0 0 0 0 0 0 0
            # blocker_index = (0x0000000002400000 * 0x4010004000200041) >> 54 = 0x0000000000000240 = 576
            # attack_table[18][577] = compute_rook_attack(18, 0x0000000002400000)
            # attack_table[18][577] =
            #       0 0 0 0 0 0 0 0
            #       0 0 0 0 0 0 0 0
            #       0 0 0 0 0 0 0 0
            #       0 0 1 0 0 0 0 0
            #       0 0 0 1 1 1 1 0
            #       0 0 1 0 0 0 0 0
            #       0 0 1 0 0 0 0 0
        # end
    # end
        
    return possible_blockers_table, magic_table, shift_table, attack_table
end

function generate_bishop_table()
    magic_table = Vector{UInt64}([
        0x40210414004040,
        0x2290100115012200,
        0xa240400a6004201,
        0x80a0420800480,
        0x4022021000000061,
        0x31012010200000,
        0x4404421051080068,
        0x1040882015000,
        0x8048c01206021210,
        0x222091024088820,
        0x4328110102020200,
        0x901cc41052000d0,
        0xa828c20210000200,
        0x308419004a004e0,
        0x4000840404860881,
        0x800008424020680,
        0x28100040100204a1,
        0x82001002080510,
        0x9008103000204010,
        0x141820040c00b000,
        0x81010090402022,
        0x14400480602000,
        0x8a008048443c00,
        0x280202060220,
        0x3520100860841100,
        0x9810083c02080100,
        0x41003000620c0140,
        0x6100400104010a0,
        0x20840000802008,
        0x40050a010900a080,
        0x818404001041602,
        0x8040604006010400,
        0x1028044001041800,
        0x80b00828108200,
        0xc000280c04080220,
        0x3010020080880081,
        0x10004c0400004100,
        0x3010020200002080,
        0x202304019004020a,
        0x4208a0000e110,
        0x108018410006000,
        0x202210120440800,
        0x100850c828001000,
        0x1401024204800800,
        0x41028800402,
        0x20642300480600,
        0x20410200800202,
        0xca02480845000080,
        0x140c404a0080410,
        0x2180a40108884441,
        0x4410420104980302,
        0x1108040046080000,
        0x8141029012020008,
        0x894081818082800,
        0x40020404628000,
        0x804100c010c2122,
        0x8168210510101200,
        0x1088148121080,
        0x204010100c11010,
        0x1814102013841400,
        0xc00010020602,
        0x1045220c040820,
        0x12400808070840,
        0x2004012a040132
    ])
    shift_table = Vector{UInt64}([
        58, 59, 59, 59, 59, 59, 59, 58,
        59, 59, 59, 59, 59, 59, 59, 59,
        59, 59, 57, 57, 57, 57, 59, 59,
        59, 59, 57, 55, 55, 57, 59, 59,
        59, 59, 57, 55, 55, 57, 59, 59,
        59, 59, 57, 57, 57, 57, 59, 59,
        59, 59, 59, 59, 59, 59, 59, 59,
        58, 59, 59, 59, 59, 59, 59, 58
    ])
    possible_blockers_table = generate_bishop_mask_table()
    attack_table = zeros(UInt64, 64, 512)

    for sq in 0:63
        possible_blockers = possible_blockers_table[sq + 1]
        nr_of_possible_blockers = 64 - shift_table[sq+1]
        
        for idx in 0:2^nr_of_possible_blockers - 1
            blocker_pattern = index_to_blocker_pattern(idx, possible_blockers, nr_of_possible_blockers)
            blocker_index = (blocker_pattern * magic_table[sq+1]) >> shift_table[sq+1]
            attack_table[sq+1, blocker_index + 1] = compute_bishop_attack(sq, blocker_pattern)
        end
    end

    return possible_blockers_table, magic_table, shift_table, attack_table
end

function MagicTable(type)
    if type == :rook    
        possible_blockers_table, magic_table, shift_table, attack_table = generate_rook_table()
    elseif type == :bishop
        possible_blockers_table, magic_table, shift_table, attack_table = generate_bishop_table()
    end

    return MagicTable(possible_blockers_table, magic_table, shift_table, attack_table)
end

function LookUpTables()
    rook_table = MagicTable(:rook)
    bishop_table = MagicTable(:bishop)
    king_table = generate_king_table()
    knight_table = generate_knight_table()
    between_table = generate_between_table()
    line_spanned_table = generate_line_spanned_table()
    square_table = generate_square_table()
    return LookUpTables(rook_table, bishop_table, king_table, knight_table, between_table, line_spanned_table, square_table)
end

const LOOKUP = LookUpTables()

@inline function rook_pseudo_attack(square, occupied::UInt64)
    idx = ((occupied & LOOKUP.rook_table.mask[square+1]) * LOOKUP.rook_table.magic[square+1]) >> LOOKUP.rook_table.shift[square+1]
    return LOOKUP.rook_table.attack_table[square+1, idx+1]
end

@inline function bishop_pseudo_attack(square, occupied::UInt64)
    idx = ((occupied & LOOKUP.bishop_table.mask[square+1]) * LOOKUP.bishop_table.magic[square+1]) >> LOOKUP.bishop_table.shift[square+1]
    return LOOKUP.bishop_table.attack_table[square+1, idx+1]
end

@inline function king_pseudo_attack(square)
    return LOOKUP.king_table[square+1]
end

@inline function knight_pseudo_attack(square)
    return LOOKUP.knight_table[square+1]
end

@inline function squares_between(square1, square2)
    return LOOKUP.between_table[square1+1, square2+1]
end

@inline function line_spanned(square1, square2)
    return LOOKUP.line_spanned_table[square1+1, square2+1]
end

@inline function bb(square)
    return LOOKUP.square_table[square + 1]
end

# end