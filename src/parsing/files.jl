function count_lines_in_files(io::IOStream)
    count = 0
    while !eof(io)
        _ = readline(io)
        count += 1
    end
    return count
end

function count_lines_in_files(path::String)
    io = open(path, "r")
    return count_lines_in_files(io)
end