# core formatting functions

### auxiliary functions

function _repwrite(out::IO, c::AbstractChar, n::Int)
    while n > 0
        write(out, c)
        n -= 1
    end
end


### print string or char

function _pfmt_s(out::IO, fs::FormatSpec, s::Union{AbstractString,AbstractChar})
    wid = fs.width
    slen = length(s)
    if wid <= slen
        write(out, s)
    else
        a = fs.align
        if a == '<'
            write(out, s)
            _repwrite(out, fs.fill, wid-slen)
        else
            _repwrite(out, fs.fill, wid-slen)
            write(out, s)
        end
    end
end


### print integers

_mul(x::Integer, ::_Dec) = x * 10
_mul(x::Integer, ::_Bin) = x << 1
_mul(x::Integer, ::_Oct) = x << 3
_mul(x::Integer, ::Union{_Hex, _HEX}) = x << 4

_div(x::Integer, ::_Dec) = div(x, 10)
_div(x::Integer, ::_Bin) = x >> 1
_div(x::Integer, ::_Oct) = x >> 3
_div(x::Integer, ::Union{_Hex, _HEX}) = x >> 4

function _ndigits(x::Integer, op)  # suppose x is non-negative
    m = 1
    q = _div(x, op)
    while q > 0
        m += 1
        q = _div(q, op)
    end
    return m
end

_ipre(op) = ""
_ipre(::Union{_Hex, _HEX}) = "0x"
_ipre(::_Oct) = "0o"
_ipre(::_Bin) = "0b"

_digitchar(x::Integer, ::_Bin) = x == 0 ? '0' : '1'
_digitchar(x::Integer, ::_Dec) = Char(Int('0') + x)
_digitchar(x::Integer, ::_Oct) = Char(Int('0') + x)
_digitchar(x::Integer, ::_Hex) = Char(x < 10 ? '0' + x : 'a' + (x - 10))
_digitchar(x::Integer, ::_HEX) = Char(x < 10 ? '0' + x : 'A' + (x - 10))

_signchar(x::Real, s::AbstractChar) = signbit(x) ? '-' :
                                s == '+' ? '+' :
                                s == ' ' ? ' ' : '\0'

function _pfmt_int(out::IO, sch::AbstractChar, ip::ASCIIStr, zs::Integer, ax::Integer, op::Op) where {Op}
    # print sign
    sch != '\0' && write(out, sch)
    # print prefix
    !isempty(ip) && write(out, ip)
    # print padding zeros
    zs > 0 && _repwrite(out, '0', zs)
    # print actual digits
    ax == 0 ? write(out, '0') : _pfmt_intdigits(out, ax, op)
    nothing
end

function _pfmt_intdigits(out::IO, ax::T, op::Op) where {Op, T<:Integer}
    b_lb = _div(ax, op)
    b = one(T)
    while b <= b_lb
        b = _mul(b, op)
    end
    r = ax
    while b > 0
        (q, r) = divrem(r, b)
        write(out, _digitchar(q, op))
        b = _div(b, op)
    end
end

function _pfmt_i(out::IO, fs::FormatSpec, x::Integer, op::Op) where {Op}
    # calculate actual length
    ax = abs(x)
    xlen = _ndigits(abs(x), op)
    # sign char
    sch = _signchar(x, fs.sign)
    if sch != '\0'
        xlen += 1
    end
    # prefix (e.g. 0x, 0b, 0o)
    ip = ""
    if fs.ipre
        ip = _ipre(op)
        xlen += length(ip)
    end

    # printing
    wid = fs.width
    if wid <= xlen
        _pfmt_int(out, sch, ip, 0, ax, op)
    elseif fs.zpad
        _pfmt_int(out, sch, ip, wid-xlen, ax, op)
    else
        a = fs.align
        if a == '<'
            _pfmt_int(out, sch, ip, 0, ax, op)
            _repwrite(out, fs.fill, wid-xlen)
        else
            _repwrite(out, fs.fill, wid-xlen)
            _pfmt_int(out, sch, ip, 0, ax, op)
        end
    end
end


### print floating point numbers

function _pfmt_float(out::IO, sch::AbstractChar, zs::Integer, intv::Real, decv::Real, prec::Int)
    # print sign
    sch != '\0' && write(out, sch)

    # print padding zeros
    zs > 0 && _repwrite(out, '0', zs)

    idecv = round(Integer, decv * exp10(prec))
    # print integer part
    if intv == 0
        write(out, '0')
    else
        _pfmt_intdigits(out, intv, _Dec())
    end
    # print decimal point
    write(out, '.')
    # print decimal part
    if prec > 0
        nd = _ndigits(idecv, _Dec())
        nd < prec && _repwrite(out, '0', prec - nd)
        _pfmt_intdigits(out, idecv, _Dec())
    end
end

function _pfmt_f(out::IO, fs::FormatSpec, x::AbstractFloat)
    # separate sign, integer, and decimal part
    rax = round(abs(x), fs.prec)
    sch = _signchar(x, fs.sign)
    intv = trunc(Integer, rax)
    decv = rax - intv

    # calculate length
    xlen = _ndigits(intv, _Dec()) + 1 + fs.prec
    sch != '\0' && (xlen += 1)

    # print
    wid = fs.width
    if wid <= xlen
        _pfmt_float(out, sch, 0, intv, decv, fs.prec)
    elseif fs.zpad
        _pfmt_float(out, sch, wid-xlen, intv, decv, fs.prec)
    else
        a = fs.align
        if a == '<'
            _pfmt_float(out, sch, 0, intv, decv, fs.prec)
            _repwrite(out, fs.fill, wid-xlen)
        else
            _repwrite(out, fs.fill, wid-xlen)
            _pfmt_float(out, sch, 0, intv, decv, fs.prec)
        end
    end
end

function _pfmt_floate(out::IO, sch::AbstractChar, zs::Integer, u::Real, prec::Int, e::Integer,
                      ec::AbstractChar)
    intv = trunc(Integer,u)
    decv = u - intv
    _pfmt_float(out, sch, zs, intv, decv, prec)
    write(out, ec)
    if e >= 0
        write(out, '+')
    else
        write(out, '-')
        e = -e
    end
    if e < 10
        write(out, '0')
    end
    _pfmt_intdigits(out, e, _Dec())
end


function _pfmt_e(out::IO, fs::FormatSpec, x::AbstractFloat)
    # extract sign, significand, and exponent
    ax = abs(x)
    sch = _signchar(x, fs.sign)
    if ax == 0.0
        e = 0
        u = zero(x)
    else
        rax = signif(ax, fs.prec + 1)
        e = floor(Integer, log10(rax))  # exponent
        u = rax * exp10(-e)  # significand
    end

    # calculate length
    xlen = 6 + fs.prec
    abs(e) > 99 && (xlen += _ndigits(abs(e), _Dec()) - 2)
    sch != '\0' && (xlen += 1)

    # print
    ec = isuppercase(fs.typ) ? 'E' : 'e'
    wid = fs.width
    if wid <= xlen
        _pfmt_floate(out, sch, 0, u, fs.prec, e, ec)
    elseif fs.zpad
        _pfmt_floate(out, sch, wid-xlen, u, fs.prec, e, ec)
    else
        a = fs.align
        if a == '<'
            _pfmt_floate(out, sch, 0, u, fs.prec, e, ec)
            _repwrite(out, fs.fill, wid-xlen)
        else
            _repwrite(out, fs.fill, wid-xlen)
            _pfmt_floate(out, sch, 0, u, fs.prec, e, ec)
        end
    end
end

function _pfmt_g(out::IO, fs::FormatSpec, x::AbstractFloat)
    # number decomposition
    ax = abs(x)
    if 1.0e-4 <= ax < 1.0e6
        _pfmt_f(out, fs, x)
    else
        _pfmt_e(out, fs, x)
    end
end

function _pfmt_specialf(out::IO, fs::FormatSpec, x::AbstractFloat)
    if isinf(x)
        if x > 0
            _pfmt_s(out, fs, "Inf")
        else
            _pfmt_s(out, fs, "-Inf")
        end
    else
        @assert isnan(x)
        _pfmt_s(out, fs, "NaN")
    end
end



