struct BoardFeatures
    hashes::Vector{UInt64}
end

function BoardFeatures(board::Board)
    hashes = Vector{UInt64}()

    for i in 0:63
        piece = board.squares[i + 1]
        if piece != EMPTY
            push!(hashes, i + 64 * piece)
        end
    end

    return BoardFeatures(hashes)
end

function Base.iterate(iter::BoardFeatures, state=1)
    if state > length(iter.hashes)
        return nothing
    end

    return (iter.hashes[state], state + 1)
end

function Base.keys(iter::BoardFeatures)
    return 1:length(iter.hashes)
end

function Base.length(iter::BoardFeatures)
    return length(iter.hashes)
end

function extract_features_from_all_boards(board::Board, legals::Vector{Move})
    features_of_all_boards = Vector{BoardFeatures}()

    for move in legals
        do_move!(board, move)
        push!(features_of_all_boards, BoardFeatures(board))
        undo_move!(board, move)
    end

    return features_of_all_boards
end