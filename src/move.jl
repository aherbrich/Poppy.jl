struct Move{type}
    src::UInt8
    dst::UInt8
end

Move(src, dst, type::UInt8) = Move{type}(src, dst)

