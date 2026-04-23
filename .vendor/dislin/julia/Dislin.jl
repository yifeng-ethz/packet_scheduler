# /****************************************************************/
# /**                        DISLIN.JL                           **/
# /**                                                            **/
# /** Module file of DISLIN for Julia.                           **/
# /**                                                            **/
# /** Date     : 15.03.2024                                      **/
# /** Functions: 800                                             **/
# /** Version  : 11.5.2, 64-bit                                  **/
# /****************************************************************/

module Dislin

function abs3pt(x1::Float64, x2::Float64, x3::Float64)
  xp1 = Cdouble[0]
  xp2 = Cdouble[0]
  ccall((:axs3pt, "libdislin_d.so"), Cvoid, (Float64, Float64, Float64,
          Ptr{Cdouble}, Ptr{Cdouble}), x1, x2, x3, xp1, xp2)
  return xp1[1], xp2[1]
end

function addlab(s1::String, x::Float64, i::Int64, s2::String)
  ccall((:aaddlab, "libdislin_d.so"), Cvoid, 
           (Ptr{UInt8}, Float64, Int32, Ptr{UInt8}), s1, x, i, s2)
end

function angle(i::Int64)
  ccall((:angle, "libdislin_d.so"), Cvoid, (Int32,), i)
end

function arcell(i1::Int64, i2::Int64, i3::Int64, i4::Int64, x1::Float64,
                x2::Float64, x3::Float64)
  ccall((:arcell, "libdislin_d.so"), Cvoid, (Int32, Int32, Int32, Int32,
           Float64, Float64, Float64), i1, i2, i3, i4, x1, x2, x3)
end

function areaf(ixray::Vector{Int32}, iyray::Vector{Int32}, n::Int64)
  ccall((:areaf, "libdislin_d.so"), Cvoid, 
         (Ptr{Int32}, Ptr{Int32}, Int32), ixray, iyray, n)
end

function autres(i1::Int64, i2::Int64)
  ccall((:autres, "libdislin_d.so"), Cvoid, (Int32, Int32), i1, i2)
end

function autres3d(i1::Int64, i2::Int64, i3::Int64)
  ccall((:autres3d, "libdislin_d.so"), Cvoid, (Int32, Int32, Int32), i1, i2, i3)
end

function ax2grf()
  ccall((:ax2grf, "libdislin_d.so"), Cvoid, ())
end

function ax3len(i1::Int64, i2::Int64, i3::Int64)
  ccall((:ax3len, "libdislin_d.so"), Cvoid, (Int32, Int32, Int32), i1, i2, i3)
end

function axclrs(i::Int64, s1::String, s2::String)
  ccall((:axclrs, "libdislin_d.so"), Cvoid, (Int32, Ptr{UInt8}, Ptr{UInt8}), 
           i, s1, s2)
end

function axends(s1::String, s2::String)
  ccall((:axends, "libdislin_d.so"), Cvoid, (Ptr{UInt8}, Ptr{UInt8}), s1, s2)
end

function axgit()
  ccall((:axgit, "libdislin_d.so"), Cvoid, ())
end

function axis3d(x1::Float64, x2::Float64, x3::Float64)
  ccall((:axis3d, "libdislin_d.so"), Cvoid, (Float64, Float64, Float64), 
          x1, x2, x3)
end

function axsbgd(i::Int64)
  ccall((:axsbgd, "libdislin_d.so"), Cvoid, (Int32,), i)
end

function axsers()
  ccall((:axsres, "libdislin_d.so"), Cvoid, ())
end

function axslen(i1::Int64, i2::Int64)
  ccall((:axslen, "libdislin_d.so"), Cvoid, (Int32, Int32), i1, i2)
end

function axsorg(i1::Int64, i2::Int64)
  ccall((:axsorg, "libdislin_d.so"), Cvoid, (Int32, Int32), i1, i2)
end

function axspos(i1::Int64, i2::Int64)
  ccall((:axspos, "libdislin_d.so"), Cvoid, (Int32, Int32), i1, i2)
end

function axsscl(s1::String, s2::String)
  ccall((:axsscl, "libdislin_d.so"), Cvoid, (Ptr{UInt8}, Ptr{UInt8}), s1, s2)
end

function axstyp(s::String)
  ccall((:axstyp, "libdislin_d.so"), Cvoid, (Ptr{UInt8},), s)
end

function barbor(i::Int64)
  ccall((:barbor, "libdislin_d.so"), Cvoid, (Int32,), i)
end

function barclr(i1::Int64, i2::Int64, i3::Int64)
  ccall((:barclr, "libdislin_d.so"), Cvoid, (Int32, Int32, Int32), i1, i2, i3)
end

function bargrp(i::Int64, x::Float64)
  ccall((:bargrp, "libdislin_d.so"), Cvoid, (Int32, Float64), i, x)
end

function barmod(s1::String, s2::String)
  ccall((:barmod, "libdislin_d.so"), Cvoid, (Ptr{UInt8}, Ptr{UInt8}), s1, s2)
end

function baropt(x1::Float64, x2::Float64)
  ccall((:baropt, "libdislin_d.so"), Cvoid, (Float64, Float64), x1, x2)
end

function barpos(s::String)
  ccall((:barpos, "libdislin_d.so"), Cvoid, (Ptr{UInt8},), s)
end

function bars(xray::Vector{Float64}, yray::Vector{Float64}, 
                zray::Vector{Float64}, n::Int64)
  ccall((:bars, "libdislin_d.so"), Cvoid, (Ptr{Float64}, Ptr{Float64}, 
          Ptr{Float64}, Int32), xray, yray, zray, n)
end

function bars3d(xray::Vector{Float64}, yray::Vector{Float64}, 
                z1ray::Vector{Float64}, z2ray::Vector{Float64},
                xwray::Vector{Float64}, ywray::Vector{Float64},
                icray::Vector{Int32}, n::Int64)
  ccall((:bars3d, "libdislin_d.so"), Cvoid, (Ptr{Float64}, Ptr{Float64}, 
          Ptr{Float64}, Ptr{Float64}, Ptr{Float64}, Ptr{Float64},
          Ptr{Int32}, Int32), xray, yray, z1ray, z2ray, xwray, ywray, icray, n)
end

function bartyp(s::String)
  ccall((:bartyp, "libdislin_d.so"), Cvoid, (Ptr{UInt8},), s)
end

function barwth(x::Float64)
  ccall((:barwth, "libdislin_d.so"), Cvoid, (Float64,), x)
end

function basalf(s::String)
  ccall((:basalf, "libdislin_d.so"), Cvoid, (Ptr{UInt8},), s)
end

function basdat(i1::Int64, i2::Int64, i3::Int64)
  ccall((:basdat, "libdislin_d.so"), Cvoid, (Int32, Int32, Int32), i1, i2, i3)
end

function bezier(xray::Vector{Float64}, yray::Vector{Float64}, nray::Int64,
                x::Vector{Float64},y::Vector{Float64}, n::Int64)
  ccall((:bezier, "libdislin_d.so"), Cvoid, (Ptr{Float64}, Ptr{Float64}, Int32,
          Ptr{Float64}, Ptr{Float64}, Int32), xray, yray, nray, x, y, n)
end

function bfcclr(i::Int64)
  ccall((:bfcclr, "libdislin_d.so"), Cvoid, (Int32,), i)
end

function bfcmsh(i::Int64)
  ccall((:bfcmsh, "libdislin_d.so"), Cvoid, (Int32,), i)
end

function bitsi2(i1::Int64, i2::Int16, i3::Int64, i4::Int16, i5::Int64)
  n = ccall((:bitsi2, "libdislin_d.so"), Int16, 
              (Int32, Int16, Int32, Int16, Int32), i1, i2, i3, i4, i5)
  return n
end

function bitsi4(i1::Int64, i2::Int32, i3::Int64, i4::Int32, i5::Int64)
  n = ccall((:bitsi2, "libdislin_d.so"), Int32, 
              (Int32, Int32, Int32, Int32, Int32), i1, i2, i3, i4, i5)
  return n
end

function bmpfnt(s::String)
  ccall((:bmpfnt, "libdislin_d.so"), Cvoid, (Ptr{UInt8},), s)
end

function bmpmod(i::Int64, s1::String, s2::String)
  ccall((:bmpmod, "libdislin_d.so"), Cvoid, (Int32, Ptr{UInt8}, Ptr{UInt8}), 
           i, s1, s2)
end

function box2d()
  ccall((:box2d, "libdislin_d.so"), Cvoid, ())
end

function box3d()
  ccall((:box3d, "libdislin_d.so"), Cvoid, ())
end

function bufmod(s1::String, s2::String)
  ccall((:bufmod, "libdislin_d.so"), Cvoid, (Ptr{UInt8}, Ptr{UInt8}), s1, s2)
end

function center()
  ccall((:center, "libdislin_d.so"), Cvoid, ())
end

function cgmbgd(x1::Float64, x2::Float64, x3::Float64)
  ccall((:cgmbgd, "libdislin_d.so"), Cvoid, (Float64, Float64, Float64), 
          x1, x2, x3)
end

function cgmpic(s::String)
  ccall((:cgmpic, "libdislin_d.so"), Cvoid, (Ptr{UInt8},), s)
end

function cmgver(i::Int64)
  ccall((:cmgver, "libdislin_d.so"), Cvoid, (Int32,), i)
end

function chaang(x::Float64)
  ccall((:chaang, "libdislin_d.so"), Cvoid, (Float64,), x)
end

function chacod(s::String)
  ccall((:chacod, "libdislin_d.so"), Cvoid, (Ptr{UInt8},), s)
end

function chaspc(x::Float64)
  ccall((:chaspc, "libdislin_d.so"), Cvoid, (Float64,), x)
end

function chawth(x::Float64)
  ccall((:chawth, "libdislin_d.so"), Cvoid, (Float64,), x)
end

function chnatt()
  ccall((:chnatt, "libdislin_d.so"), Cvoid, ())
end

function chncrv(s::String)
  ccall((:chncrv, "libdislin_d.so"), Cvoid, (Ptr{UInt8},), s)
end

function chndot()
  ccall((:chndot, "libdislin_d.so"), Cvoid, ())
end

function chndsh()
  ccall((:chndsh, "libdislin_d.so"), Cvoid, ())
end

function chnbar(s::String)
  ccall((:chnbar, "libdislin_d.so"), Cvoid, (Ptr{UInt8},), s)
end

function chnpie(s::String)
  ccall((:chnpie, "libdislin_d.so"), Cvoid, (Ptr{UInt8},), s)
end

function circ3p(x1::Float64, x2::Float64, x3::Float64, 
                x4::Float64, x5::Float64, x6::Float64)
  xp1 = Cdouble[0]
  xp2 = Cdouble[0]
  xp3 = Cdouble[0]
  ccall((:circ3p, "libdislin_d.so"), Cvoid, (Float64, Float64, Float64,
          Float64, Float64, Float64, Ptr{Cdouble}, Ptr{Cdouble}, Ptr{Cdouble}),
          x1, x2, x3, x4, x5, x6, xp1, xp2, xp3)
  return xp1[1], xp2[1], xp3[1] 
end

function circle(i1::Int64, i2::Int64, i3::Int64)
  ccall((:circle, "libdislin_d.so"), Cvoid, (Int32, Int32, Int32), i1, i2, i3)
end

function circsp(i::Int64)
  ccall((:circsp, "libdislin_d.so"), Cvoid, (Int32,), i)
end

function clip3d(s::String)
  ccall((:clip3d, "libdislin_d.so"), Cvoid, (Ptr{UInt8},), s)
end

function closfl(i::Int64)
  n = ccall((:closfl, "libdislin_d.so"), Int32, (Int32, ), i)
  return convert(Int64, n)
end

function clpbor(s::String)
  ccall((:clpbor, "libdislin_d.so"), Cvoid, (Ptr{UInt8},), s)
end

function clpmod(s::String)
  ccall((:clpmod, "libdislin_d.so"), Cvoid, (Ptr{UInt8},), s)
end

function clpwin(i1::Int64, i2::Int64, i3::Int64, i4::Int64)
  ccall((:clpwin, "libdislin_d.so"), Cvoid, (Int32, Int32, Int32, Int32), 
           i1, i2, i3, i4)
end

function clrcyc(i1::Int64, i2::Int64)
  ccall((:clrcyc, "libdislin_d.so"), Cvoid, (Int32, Int32), i1, i2)
end

function clrmod(s::String)
  ccall((:clrmod, "libdislin_d.so"), Cvoid, (Ptr{UInt8},), s)
end

function clswin(i::Int64)
  ccall((:clswin, "libdislin_d.so"), Cvoid, (Int32,), i)
end

function color(s::String)
  ccall((:color, "libdislin_d.so"), Cvoid, (Ptr{UInt8},), s)
end

function colran(i1::Int64, i2::Int64)
  ccall((:colran, "libdislin_d.so"), Cvoid, (Int32, Int32), i1, i2)
end

function conray(zray::Vector{Float64}, nray::Vector{Int32}, n::Int64)
  ccall((:colray, "libdislin_d.so"), Cvoid, 
          (Ptr{Float64}, Ptr{Int32}, Int32), zray, nray, n)
end

function complx()
  ccall((:complx, "libdislin_d.so"), Cvoid, ())
end

function conclr(nray::Vector{Int32}, n::Int64)
  ccall((:conclr, "libdislin_d.so"), Cvoid, (Ptr{Int32}, Int32), nray, n)
end

function concrv(xray::Vector{Float64}, yray::Vector{Float64}, n::Int64,
                zlev::Float64)
  ccall((:concrv, "libdislin_d.so"), Cvoid, 
          (Ptr{Float64}, Ptr{Float64}, Int32, Float64), xray, yray, n, zlev)
end

function cone3d(x1::Float64, x2::Float64, x3::Float64, x4::Float64,
           x5::Float64, x6::Float64, i1::Int64, i2::Int64)
  ccall((:cone3d, "libdislin_d.so"), Cvoid, (Float64, Float64, Float64,
          Float64, Float64, Float64, Int32, Int32), 
          x1, x2, x3, x4, x5, x6, i1, i2)
end
 
function confll(xray::Vector{Float64}, yray::Vector{Float64}, 
                zray::Vector{Float64}, n::Int64, i1ray::Vector{Int32}, 
                i2ray::Vector{Int32}, i3ray::Vector{Int32}, ntri::Int64,
                zlev::Vector{Float64}, nlev::Int64)
  ccall((:confll, "libdislin_d.so"), Cvoid, (Ptr{Float64}, Ptr{Float64}, 
          Ptr{Float64}, Int32, Ptr{Int32}, Ptr{Int32}, Ptr{Int32}, Int32,
          Ptr{Float64}, Int32), xray, yray, zray, n, i1ray, i2ray, i3ray,
          ntri, zlev, nlev)
end

function congap(x::Float64)
  ccall((:congap, "libdislin_d.so"), Cvoid, (Float64,), x)
end

function conlab(s::String)
  ccall((:conlab, "libdislin_d.so"), Cvoid, (Ptr{UInt8},), s)
end

function conmat(zmat::Array{Float64, 2}, n::Int64, m::Int64, zlev::Float64)
  z = transpose(zmat)
  ccall((:conmat, "libdislin_d.so"), Cvoid, (Ptr{Float64}, Int32, Int32, 
          Float64), z, n, m, zlev)
  z = 0  # free z
end

function conmod(x1::Float64, x2::Float64)
  ccall((:conmod, "libdislin_d.so"), Cvoid, (Float64, Float64), x1, x2)
end

function conn3d(x1::Float64, x2::Float64, x3::Float64)
  ccall((:conn3d, "libdislin_d.so"), Cvoid, (Float64, Float64, Float64), 
          x1, x2, x3)
end

function connpt(x1::Float64, x2::Float64)
  ccall((:connpt, "libdislin_d.so"), Cvoid, (Float64, Float64), x1, x2)
end

function conpts(xray::Vector{Float64}, n::Int64, yray::Vector{Float64},
                m::Int64, zmat::Array{Float64, 2}, zlev::Float64,
                xpts::Vector{Float64}, ypts::Vector{Float64}, maxpts::Int64,
                nray::Vector{Int32}, maxray::Int64)
  z = transpose(zmat)
  nlines = Cint[0]
  ccall((:conpts, "libdislin_d.so"), Cvoid, (Ptr{Float64}, Int32, Ptr{Float64}, 
          Int32, Ptr{Float64}, Float64, Ptr{Float64}, Ptr{Float64}, Int32,
          Ptr{Int32}, Int32, Ptr{Cint}), xray, n, yray, m, z, zlev, xpts, ypts,
          maxpts, nray, maxray, nlines)
  z = 0
  return convert(Int64, nlines[1])
end

function conshd(xray::Vector{Float64}, n::Int64, yray::Vector{Float64},
                m::Int64, zmat::Array{Float64, 2}, zlev::Vector{Float64},
                nlev::Int64)
  z = transpose(zmat)
  ccall((:conshd, "libdislin_d.so"), Cvoid, (Ptr{Float64}, Int32, Ptr{Float64}, 
          Int32, Ptr{Float64}, Ptr{Float64}, Int32), xray, n, yray, m, z, 
          zlev, nlev)
  z = 0  # free z
end

function conshd2(xmat::Array{Float64, 2}, ymat::Array{Float64, 2},
                zmat::Array{Float64, 2}, n::Int64, m::Int64, 
                zlev::Vector{Float64}, nlev::Int64)
  x = transpose(xmat)
  y = transpose(ymat)
  z = transpose(zmat)
  ccall((:conshd2, "libdislin_d.so"), Cvoid, (Ptr{Float64}, Ptr{Float64}, 
          Ptr{Float64}, Int32, Int32, Ptr{Float64}, Int32), x, y, z, n, m, 
          zlev, nlev)
  x = 0 
  y = 0 
  z = 0 
end

function conshd3d(xray::Vector{Float64}, n::Int64, yray::Vector{Float64},
                m::Int64, zmat::Array{Float64, 2}, zlev::Vector{Float64},
                nlev::Int64)
  z = transpose(zmat)
  ccall((:conshd3d, "libdislin_d.so"), Cvoid, (Ptr{Float64}, Int32, Ptr{Float64},
          Int32, Ptr{Float64}, Ptr{Float64}, Int32), xray, n, yray, m, z, 
          zlev, nlev)
  z = 0  # free z
end

function contri(xray::Vector{Float64}, yray::Vector{Float64}, 
                zray::Vector{Float64}, n::Int64, i1ray::Vector{Int32}, 
                i2ray::Vector{Int32}, i3ray::Vector{Int32}, ntri::Int64,
                zlev::Float64)
  ccall((:contri, "libdislin_d.so"), Cvoid, (Ptr{Float64}, Ptr{Float64}, 
          Ptr{Float64}, Int32, Ptr{Int32}, Ptr{Int32}, Ptr{Int32}, Int32,
          Float64), xray, yray, zray, n, i1ray, i2ray, i3ray, ntri, zlev)
end

function contur(xray::Vector{Float64}, n::Int64, yray::Vector{Float64},
                m::Int64, zmat::Array{Float64, 2}, zlev::Float64)
  z = transpose(zmat)
  ccall((:contur, "libdislin_d.so"), Cvoid, (Ptr{Float64}, Int32, Ptr{Float64}, 
          Int32, Ptr{Float64}, Float64), xray, n, yray, m, z, zlev)
  z = 0  # free z
end

function contur2(xmat::Array{Float64, 2}, ymat::Array{Float64, 2},
                zmat::Array{Float64, 2}, n::Int64, m::Int64, zlev::Float64)
  x = transpose(xmat)
  y = transpose(ymat)
  z = transpose(zmat)
  ccall((:contur2, "libdislin_d.so"), Cvoid, (Ptr{Float64}, Ptr{Float64}, 
          Ptr{Float64}, Int32, Int32, Float64), x, y, z, n, m, zlev)
  x = 0 
  y = 0 
  z = 0 
end

function cross()
  ccall((:cross, "libdislin_d.so"), Cvoid, ())
end

function crvmat(zmat::Array{Float64, 2}, n::Int64, m::Int64, ixpts::Int64, 
                iypts::Int64)
  z = transpose(zmat)
  ccall((:crvmat, "libdislin_d.so"), Cvoid, (Ptr{Float64}, Int32, Int32, Int32, 
           Int32), z, n, m, ixpts, iypts)
  z = 0  # free z
end

function crvqdr(xray::Vector{Float64}, yray::Vector{Float64}, 
                zray::Vector{Float64}, n::Int64)
  ccall((:crvqdr, "libdislin_d.so"), Cvoid, (Ptr{Float64}, Ptr{Float64}, 
          Ptr{Float64}, Int32), xray, yray, zray, n)
end

function crvt3d(xray::Vector{Float64}, yray::Vector{Float64}, 
                zray::Vector{Float64}, rray::Vector{Float64},
                icray::Vector{Int32}, n::Int64)
  ccall((:crvt3d, "libdislin_d.so"), Cvoid, (Ptr{Float64}, Ptr{Float64}, 
          Ptr{Float64}, Ptr{Float64}, Ptr{Int32}, Int32), 
          xray, yray, zray, rray, icray, n)
end

function crvtri(xray::Vector{Float64}, yray::Vector{Float64}, 
                zray::Vector{Float64}, n::Int64, i1ray::Vector{Int32},
                i2ray::Vector{Int32}, i3ray::Vector{Int32}, ntri::Int64)
  ccall((:crvtri, "libdislin_d.so"), Cvoid, (Ptr{Float64}, Ptr{Float64}, 
          Ptr{Float64}, Int32, Ptr{Int32}, Ptr{Int32}, Ptr{Int32}, Int32), 
          xray, yray, zray, n, i1ray, i2ray, i3ray, ntri)
end

function csrkey()
  n = ccall((:csrkey, "libdislin_d.so"), Int32, ())
  return convert(Int64, n)
end

function csrlin()
  i1 = Cint[0]
  i2 = Cint[0]
  i3 = Cint[0]
  i4 = Cint[0]
  ccall((:csrlin, "libdislin_d.so"), Cvoid, (Ptr{Cint}, Ptr{Cint}, Ptr{Cint},
           Ptr{Cint}), i1, i2, i3, i4)
  return convert(Int64, i1[1]), convert(Int64, i2[1]), convert(Int64, i3[1]),
         convert(Int64, i4[1])
end

function csrmod(s1::String, s2::String)
  ccall((:csrmod, "libdislin_d.so"), Cvoid, (Ptr{UInt8}, Ptr{UInt8}), s1, s2)
end

function csrpol(ixray::Vector{Int32}, iyray::Vector{Int32}, nmax::Int64)
  i1 = Cint[0]
  i2 = Cint[0]
  ccall((:csrpol, "libdislin_d.so"), Cvoid, 
          (Ptr{Int32}, Ptr{Int32}, Int32, Ptr{Cint}, Ptr{Cint}), 
          ixray, iyray, nmax, i1, i2)
  return convert(Int64, i1[1])
end

function csrpos()
  i1 = Cint[0]
  i2 = Cint[0]
  n = ccall((:csrpos, "libdislin_d.so"), Int32, (Ptr{Cint}, Ptr{Cint}), i1, i2)
  return convert(Int64, i1[1]), convert(Int64, i2[1]), n
end

function csrpt1()
  i1 = Cint[0]
  i2 = Cint[0]
  ccall((:csrpt1, "libdislin_d.so"), Cvoid, (Ptr{Cint}, Ptr{Cint}), i1, i2)
  return convert(Int64, i1[1]), convert(Int64, i2[1])
end

function csrpts(ixray::Vector{Int32}, iyray::Vector{Int32}, nmax::Int64)
  i1 = Cint[0]
  i2 = Cint[0]
  ccall((:csrpts, "libdislin_d.so"), Cvoid, 
          (Ptr{Int32}, Ptr{Int32}, Int32, Ptr{Cint}, Ptr{Cint}), 
          ixray, iyray, nmax, i1, i2)
  return convert(Int64, i1[1])
end

function csrmov(ixray::Vector{Int32}, iyray::Vector{Int32}, nmax::Int64)
  i1 = Cint[0]
  i2 = Cint[0]
  ccall((:csrmov, "libdislin_d.so"), Cvoid, 
          (Ptr{Int32}, Ptr{Int32}, Int32, Ptr{Cint}, Ptr{Cint}), 
          ixray, iyray, nmax, i1, i2)
  return convert(Int64, i1[1])
end

function csrrec()
  i1 = Cint[0]
  i2 = Cint[0]
  i3 = Cint[0]
  i4 = Cint[0]
  ccall((:csrreg, "libdislin_d.so"), Cvoid, (Ptr{Cint}, Ptr{Cint}, Ptr{Cint},
           Ptr{Cint}), i1, i2, i3, i4)
  return convert(Int64, i1[1]), convert(Int64, i2[1]), convert(Int64, i3[1]),
         convert(Int64, i4[1])
end

function csrtyp(s::String)
  ccall((:csrtyp, "libdislin_d.so"), Cvoid, (Ptr{UInt8},), s)
end

function csruni(s::String)
  ccall((:csruni, "libdislin_d.so"), Cvoid, (Ptr{UInt8},), s)
end

function curv3d(xray::Vector{Float64}, yray::Vector{Float64}, 
                zray::Vector{Float64}, n::Int64)
  ccall((:curv3d, "libdislin_d.so"), Cvoid, (Ptr{Float64}, Ptr{Float64}, 
          Ptr{Float64}, Int32), xray, yray, zray, n)
end

function curve(xray::Vector{Float64}, yray::Vector{Float64}, n::Int64)
  ccall((:curve, "libdislin_d.so"), Cvoid, 
          (Ptr{Float64}, Ptr{Float64}, Int32), xray, yray, n)
end

function curve3(xray::Vector{Float64}, yray::Vector{Float64}, 
                zray::Vector{Float64}, n::Int64)
  ccall((:curve3, "libdislin_d.so"), Cvoid, (Ptr{Float64}, Ptr{Float64}, 
          Ptr{Float64}, Int32), xray, yray, zray, n)
end

function curvmp(xray::Vector{Float64}, yray::Vector{Float64}, n::Int64)
  ccall((:curvmp, "libdislin_d.so"), Cvoid, 
         (Ptr{Float64}, Ptr{Float64}, Int32), xray, yray, n)
end

function curvx3(xray::Vector{Float64}, y::Float64, 
                zray::Vector{Float64}, n::Int64)
  ccall((:curvx3, "libdislin_d.so"), Cvoid, (Ptr{Float64}, Float64, 
          Ptr{Float64}, Int32), xray, y, zray, n)
end

function curvy3(x::Float64, yray::Vector{Float64}, 
                zray::Vector{Float64}, n::Int64)
  ccall((:curvy3, "libdislin_d.so"), Cvoid, (Float64, Ptr{Float64}, 
          Ptr{Float64}, Int32), x, yray, zray, n)
end

function cyli3d(x1::Float64, x2::Float64, x3::Float64, x4::Float64,
           x5::Float64, i1::Int64, i2::Int64)
  ccall((:cyli3d, "libdislin_d.so"), Cvoid, (Float64, Float64, Float64,
          Float64, Float64, Int32, Int32), 
          x1, x2, x3, x4, x5, i1, i2)
end

function dash()
  ccall((:dash, "libdislin_d.so"), Cvoid, ())
end

function dasl()
  ccall((:dashl, "libdislin_d.so"), Cvoid, ())
end

function dashm()
  ccall((:dashm, "libdislin_d.so"), Cvoid, ())
end

function dbffin()
  ccall((:dbffin, "libdislin_d.so"), Cvoid, ())
end

function dbfini()
  n = ccall((:dbfini, "libdislin_d.so"), Int32, ())
  return convert(Int64, n)
end

function dbfmod(s::String)
  ccall((:dbfmod, "libdislin_d.so"), Cvoid, (Ptr{UInt8},), s)
end

function delglb()
  ccall((:delglb, "libdislin_d.so"), Cvoid, ())
end

function digits(i::Int64, s::String)
  ccall((:digits, "libdislin_d.so"), Cvoid, (Int32, Ptr{UInt8}), i, s)
end

function disalf()
  ccall((:disalf, "libdislin_d.so"), Cvoid, ())
end

function disenv(s::String)
  ccall((:disenv, "libdislin_d.so"), Cvoid, (Ptr{UInt8},), s)
end

function disfin()
  ccall((:disfin, "libdislin_d.so"), Cvoid, ())
end

function disini()
  ccall((:disini, "libdislin_d.so"), Cvoid, ())
end

function disk3d(x1::Float64, x2::Float64, x3::Float64, x4::Float64,
           x5::Float64, i1::Int64, i2::Int64)
  ccall((:disk3d, "libdislin_d.so"), Cvoid, (Float64, Float64, Float64,
          Float64, Float64, Int32, Int32), 
          x1, x2, x3, x4, x5, i1, i2)
end

function doevnt()
  ccall((:doevnt, "libdislin_d.so"), Cvoid, ())
end

function dot()
  ccall((:dot, "libdislin_d.so"), Cvoid, ())
end

function dotl()
  ccall((:dotl, "libdislin_d.so"), Cvoid, ())
end

function duplx()
  ccall((:duplx, "libdislin_d.so"), Cvoid, ())
end

function dwgbut(s::String, i::Int64)
  n = ccall((:dwgbut, "libdislin_d.so"), Int32, (Ptr{UInt8}, Int32), s, i)
  return convert(Int64, n)
end

function dwgerr()
  n = ccall((:dwgerr, "libdislin_d.so"), Int32, ())
end

function dwgfil(s1::String, s2::String, s3::String)
  p = ccall((:dwgfil, "libdislin_d.so"), Cstring, (Ptr{UInt8}, Ptr{UInt8},
              Ptr{UInt8}), s1, s2, s3)
  return bytestring(p)
end

function dwglis(s1::String, s2::String, i::Int64)
  n = ccall((:dwglis, "libdislin_d.so"), Int32, (Ptr{UInt8}, Ptr{UInt8},
              Int32), s1, s2, i)
  return convert(Int64, n)
end

function dwgmsg(s::String)
  ccall((:dwgmsg, "libdislin_d.so"), Cvoid, (Ptr{UInt8},), s)
end

function dwgtxt(s1::String, s2::String)
  p = ccall((:dwgtxt, "libdislin_d.so"), Cstring, (Ptr{UInt8}, Ptr{UInt8}),
              s1, s2)
  return bytestring(p)
end

function ellips(i1::Int64, i2::Int64, i3::Int64, i4::Int64)
  ccall((:ellips, "libdislin_d.so"), Cvoid, (Int32, Int32, Int32, Int32), 
           i1, i2, i3, i4)
end

function endgrf()
  ccall((:endgrf, "libdislin_d.so"), Cvoid, ())
end

function erase()
  ccall((:erase, "libdislin_d.so"), Cvoid, ())
end

function errbar(xray::Vector{Float64}, yray::Vector{Float64}, 
                err1::Vector{Float64}, err2::Vector{Float64}, n::Int64)
  ccall((:errbar, "libdislin_d.so"), Cvoid, (Ptr{Float64}, Ptr{Float64}, 
          Ptr{Float64}, Ptr{Float64}, Int32), xray, yray, err1, err2, n)
end

function errdev(s::String)
  ccall((:errdev, "libdislin_d.so"), Cvoid, (Ptr{UInt8},), s)
end

function errfil(s::String)
  ccall((:errfil, "libdislin_d.so"), Cvoid, (Ptr{UInt8},), s)
end

function errmod(s1::String, s2::String)
  ccall((:errmod, "libdislin_d.so"), Cvoid, (Ptr{UInt8}, Ptr{UInt8}), s1, s2)
end

function eushft(s1::String, s2::String)
  ccall((:eushft, "libdislin_d.so"), Cvoid, (Ptr{UInt8}, Ptr{UInt8}), s1, s2)
end

function expimg(s1::String, s2::String)
  ccall((:expimg, "libdislin_d.so"), Cvoid, (Ptr{UInt8}, Ptr{UInt8}), s1, s2)
end

function expzlb(s::String)
  ccall((:expzlb, "libdislin_d.so"), Cvoid, (Ptr{UInt8},), s)
end

function fbars(xray::Vector{Float64}, y1ray::Vector{Float64}, 
                y2ray::Vector{Float64}, y3ray::Vector{Float64}, 
                y4ray::Vector{Float64}, n::Int64)
  ccall((:fbars, "libdislin_d.so"), Cvoid, (Ptr{Float64}, Ptr{Float64}, 
          Ptr{Float64}, Ptr{Float64}, Ptr{Float64}, Int32), xray, y1ray, 
          y2ray, y3ray, y4ray, n)
end

function fcha(x::Float64, i::Int64)
  s = Array{UInt8}(undef, 80)
  n = ccall((:fcha, "libdislin_d.so"), Cvoid, (Float64, Int32, Ptr{UInt8}), 
              x, i, s)
  n = ccall((:trmlen, "libdislin_d.so"), Int32, (Ptr{UInt8}, ), s)
  resize!(s, n)
  GC.@preserve s
  return unsafe_string(pointer(s))
end

function field(xray::Vector{Float64}, yray::Vector{Float64}, 
               uray::Vector{Float64}, vray::Vector{Float64}, 
               n::Int64, nvec::Int64)
  ccall((:field, "libdislin_d.so"), Cvoid, (Ptr{Float64}, Ptr{Float64}, 
          Ptr{Float64}, Ptr{Float64}, Int32, Int32), xray, yray, 
          uray, vray, n, nvec)
end

function field3d(x1ray::Vector{Float64}, y1ray::Vector{Float64}, 
                 z1ray::Vector{Float64}, x2ray::Vector{Float64}, 
                 y2ray::Vector{Float64}, z2ray::Vector{Float64}, 
                 n::Int64, nvec::Int64)
  ccall((:field3d, "libdislin_d.so"), Cvoid, (Ptr{Float64}, Ptr{Float64}, 
          Ptr{Float64}, Ptr{Float64}, Ptr{Float64}, Ptr{Float64},
          Int32, Int32), x1ray, y1ray, z1ray, x2ray, y2ray, z2ray, n, nvec)
end

function filbox(i1::Int64, i2::Int64, i3::Int64, i4::Int64)
  ccall((:filbox, "libdislin_d.so"), Cvoid, (Int32, Int32, Int32, Int32), 
           i1, i2, i3, i4)
end

function filclr(s::String)
  ccall((:filclr, "libdislin_d.so"), Cvoid, (Ptr{UInt8},), s)
end

function filmod(s::String)
  ccall((:filmod, "libdislin_d.so"), Cvoid, (Ptr{UInt8},), s)
end

function filopt(s1::String, s2::String)
  ccall((:filopt, "libdislin_d.so"), Cvoid, (Ptr{UInt8}, Ptr{UInt8}), s1, s2)
end

function filsiz(s::String)
  i1 = Cint[0]
  i2 = Cint[0]
  n = ccall((:filsiz, "libdislin_d.so"), Int32, (Ptr{UInt8}, Ptr{Cint}, 
              Ptr{Cint}), s, i1, i2)
  return convert(Int64, n), convert(Int64, i1[1]), convert(Int64, i2[1])
end

function filtyp(s::String)
  n = ccall((:filtyp, "libdislin_d.so"), Int32, (Ptr{UInt8}, ), s)
  return convert(Int64, n)
end

function filwin(i1::Int64, i2::Int64, i3::Int64, i4::Int64)
  ccall((:filwin, "libdislin_d.so"), Cvoid, (Int32, Int32, Int32, Int32), 
           i1, i2, i3, i4)
end

function fitscls()
  ccall((:fitscls, "libdislin_d.so"), Cvoid, ())
end

function fitsflt(s::String)
  x = ccall((:fitsflt, "libdislin_d.so"), Float64, (Ptr{UInt8}, ), s)
  return x
end

function fitshdu(i::Int64)
  n = ccall((:fitshdu, "libdislin_d.so"), Int32, (Int32,), i)
  return convert(Int64, n)
end

function fitsimg(iray::Vector{UInt8}, nmax::Int64) 
  n = ccall((:fitsimg, "libdislin_d.so"), Int32, (Ptr{UInt8}, Int32),
          iray, nmax)
  return convert(Int64, n)
end

function fitsopn(s::String)
  n = ccall((:fitsopn, "libdislin_d.so"), Int32, (Ptr{UInt8}, ), s)
  return convert(Int64, n)
end

function fitsstr(s::String)
  s2 = Array{UInt8}(undef, 257)
  ccall((:fitsstr, "libdislin_d.so"), Cvoid, (Ptr{UInt8}, Ptr{UInt8}, Int32), 
          s, s2, 257)
  n = ccall((:trmlen, "libdislin_d.so"), Int32, (Ptr{UInt8}, ), s2)
  resize!(s2, n)
  GC.@preserve s2
  return unsafe_string(pointer(s2))
end

function fitstyp(s::String)
  n = ccall((:fitstyp, "libdislin_d.so"), Int32, (Ptr{UInt8}, ), s)
  return convert(Int64, n)
end

function fitsval(s::String)
  n = ccall((:fitsval, "libdislin_d.so"), Int32, (Ptr{UInt8}, ), s)
  return convert(Int64, n)
end

function fixspc(x::Float64)
  ccall((:fixspc, "libdislin_d.so"), Cvoid, (Float64,), x)
end

function flab3d()
  ccall((:flab3d, "libdislin_d.so"), Cvoid, ())
end

function flen(x::Float64, i::Int64)
  n = ccall((:flen, "libdislin_d.so"), Cvoid, (Float64, Int32, ), x, i)
  return convert(Int64, n)
end

function frame(i::Int64)
  ccall((:frame, "libdislin_d.so"), Cvoid, (Int32,), i)
end

function frmbar(i::Int64)
  ccall((:frmbar, "libdislin_d.so"), Cvoid, (Int32,), i)
end

function frmclr(i::Int64)
  ccall((:frmclr, "libdislin_d.so"), Cvoid, (Int32,), i)
end

function frmess(i::Int64)
  ccall((:frmess, "libdislin_d.so"), Cvoid, (Int32,), i)
end

function gapcrv(x::Float64)
  ccall((:gapcrv, "libdislin_d.so"), Cvoid, (Float64,), x)
end

function gapsiz(x::Float64, s::String)
  ccall((:gapsiz, "libdislin_d.so"), Cvoid, (Float64, Ptr{UInt8}), x, s)
end

function gaxpar(v1::Float64, v2::Float64, s1::String, s2::String)
  x1 = Cdouble[0]
  x2 = Cdouble[0]
  x3 = Cdouble[0]
  x4 = Cdouble[0]
  i  = Cint[0]
  ccall((:gaxpar, "libdislin_d.so"), Cvoid, (Float64, Float64, Ptr{UInt8}, 
          Ptr{UInt8}, Ptr{Cdouble}, Ptr{Cdouble}, Ptr{Cdouble}, 
          Ptr{Cdouble}, Ptr{Cint}), 
          v1, v2, s1, s2, x1, x2, x3, x4, i)
  return x1[1], x2[1], x3[1], x4[1], convert(Int64, i[1])
end

function getalf()
  p = ccall((:getalf, "libdislin_d.so"), Cstring, ())
  return bytestring(p)
end

function getang()
  n = ccall((:getang, "libdislin_d.so"), Int32, ())
  return convert(Int64, n)
end

function getbpp()
  n = ccall((:getbpp, "libdislin_d.so"), Int32, ())
  return convert(Int64, n)
end

function getclp()
  i1 = Cint[0]
  i2 = Cint[0]
  i3 = Cint[0]
  i4 = Cint[0]
  ccall((:getclp, "libdislin_d.so"), Cvoid, (Ptr{Cint}, Ptr{Cint}, Ptr{Cint},
           Ptr{Cint}), i1, i2, i3, i4)
  return convert(Int64, i1[1]), convert(Int64, i2[1]), convert(Int64, i3[1]),
         convert(Int64, i4[1])
end

function getclr()
  n = ccall((:getclr, "libdislin_d.so"), Int32, ())
  return convert(Int64, n)
end

function getdig()
  i1 = Cint[0]
  i2 = Cint[0]
  i3 = Cint[0]
  ccall((:getdig, "libdislin_d.so"), Cvoid, (Ptr{Cint}, Ptr{Cint}, Ptr{Cint}), 
           i1, i2, i3)
  return convert(Int64, i1[1]), convert(Int64, i2[1]), convert(Int64, i3[1])
end

function getdsp()
  p = ccall((:getdsp, "libdislin_d.so"), Cstring, ())
  return bytestring(p)
end

function getfil()
  p = ccall((:getfil, "libdislin_d.so"), Cstring, ())
  return bytestring(p)
end

function getgrf(s::String)
  x1 = Cdouble[0]
  x2 = Cdouble[0]
  x3 = Cdouble[0]
  x4 = Cdouble[0]
  ccall((:getgrf, "libdislin_d.so"), Cvoid, (Ptr{Cdouble}, Ptr{Cdouble}, 
          Ptr{Cdouble}, Ptr{Cdouble}, Ptr{UInt8}), x1, x2, x3, x4, s)
  return x1[1], x2[1], x3[1], x4[1]
end

function gethgt()
  n = ccall((:gethgt, "libdislin_d.so"), Int32, ())
  return convert(Int64, n)
end

function gethnm()
  n = ccall((:gethnm, "libdislin_d.so"), Int32, ())
  return convert(Int64, n)
end

function getico(x1::Float64, x2::Float64)
  xp1 = Cdouble[0]
  xp2 = Cdouble[0]
  ccall((:getico, "libdislin_d.so"), Cvoid, (Float64, Float64, 
          Ptr{Cdouble}, Ptr{Cdouble}), x1, x2, xp1, xp2)
  return xp1[1], xp2[1]
end

function getind(i::Int64)
  x1 = Cdouble[0]
  x2 = Cdouble[0]
  x3 = Cdouble[0]
  ccall((:getind, "libdislin_d.so"), Cvoid, (Int32, Ptr{Cdouble}, Ptr{Cdouble}, 
          Ptr{Cdouble}), i, x1, x2, x3)
  return x1[1], x2[1], x3[1]
end

function getlab()
  s1 = Array{UInt8}(undef, 8);
  s2 = Array{UInt8}(undef, 8);
  s3 = Array{UInt8}(undef, 8);
  ccall((:getlab, "libdislin_d.so"), Cvoid, (Ptr{UInt8}, Ptr{UInt8},
          Ptr{UInt8}), s1, s2, s3)
  n1 = ccall((:trmlen, "libdislin_d.so"), Int32, (Ptr{UInt8}, ), s1)
  n2 = ccall((:trmlen, "libdislin_d.so"), Int32, (Ptr{UInt8}, ), s2)
  n3 = ccall((:trmlen, "libdislin_d.so"), Int32, (Ptr{UInt8}, ), s3)
  resize!(s1, n1)
  resize!(s2, n2)
  resize!(s3, n3)
  GC.@preserve s1
  GC.@preserve s2
  GC.@preserve s3
  return unsafe_string(pointer(s1)), unsafe_string(pointer(s2)),
         unsafe_string(pointer(s3))
end

function getlen()
  i1 = Cint[0]
  i2 = Cint[0]
  i3 = Cint[0]
  ccall((:getlen, "libdislin_d.so"), Cvoid, (Ptr{Cint}, Ptr{Cint}, Ptr{Cint}), 
           i1, i2, i3)
  return convert(Int64, i1[1]), convert(Int64, i2[1]), convert(Int64, i3[1])
end

function getlev()
  n = ccall((:getlev, "libdislin_d.so"), Int32, ())
  return convert(Int64, n)
end

function getlin()
  n = ccall((:getlin, "libdislin_d.so"), Int32, ())
  return convert(Int64, n)
end

function getlit(x1::Float64, x2::Float64, x3::Float64, x4::Float64, 
                x5::Float64, x6::Float64)
  n = ccall((:getlit, "libdislin_d.so"), Cvoid, (Float64, Float64, Float64, 
              Float64, Float64, Float64), x1, x2, x3, x4, x5, x6)
  return convert(Int64, n)
end

function getmat(xray::Vector{Float64}, yray::Vector{Float64}, 
                zray::Vector{Float64}, n::Int64, zmat::Array{Float64, 2},
                nx::Int64, ny::Int64, zval::Float64)     
  imat = Array{Int32}(undef, nx, ny)
  wmat = Array{Float64}(undef, nx, ny)
  z = Array{Float64}(undef, nx, ny)
  ccall((:getmat, "libdislin_d.so"), Cvoid, (Ptr{Float64}, Ptr{Float64}, 
          Ptr{Float64}, Int32, Ptr{Float64}, Int32, Int32, Float64,
          Ptr{Int32},Ptr{Float64}), 
          xray, yray, zray, n, z, nx, ny, zval, imat, wmat)

  transpose!(zmat, z)
  imat = 0
  wmat = 0
  z = 0
end

function getmfl()
  p = ccall((:getmfl, "libdislin_d.so"), Cstring, ())
  return bytestring(p)
end

function getmix(s::String)
  p = ccall((:getmix, "libdislin_d.so"), Cstring, (Ptr{UInt8}, ), s)
  return bytestring(p)
end

function getor()
  i1 = Cint[0]
  i2 = Cint[0]
  ccall((:getor, "libdislin_d.so"), Cvoid, (Ptr{Cint}, Ptr{Cint}), i1, i2)
  return convert(Int64, i1[1]), convert(Int64, i2[1])
end

function getpag()
  i1 = Cint[0]
  i2 = Cint[0]
  ccall((:getpag, "libdislin_d.so"), Cvoid, (Ptr{Cint}, Ptr{Cint}), i1, i2)
  return convert(Int64, i1[1]), convert(Int64, i2[1])
end

function getpat()
  n = ccall((:getpat, "libdislin_d.so"), Int32, ())
  return convert(Int64, n)
end

function getplv()
  n = ccall((:getplv, "libdislin_d.so"), Int32, ())
  return convert(Int64, n)
end

function getpos()
  i1 = Cint[0]
  i2 = Cint[0]
  ccall((:getpos, "libdislin_d.so"), Cvoid, (Ptr{Cint}, Ptr{Cint}), i1, i2)
  return convert(Int64, i1[1]), convert(Int64, i2[1])
end

function getran()
  i1 = Cint[0]
  i2 = Cint[0]
  ccall((:getran, "libdislin_d.so"), Cvoid, (Ptr{Cint}, Ptr{Cint}), i1, i2)
  return convert(Int64, i1[1]), convert(Int64, i2[1])
end

function getres()
  i1 = Cint[0]
  i2 = Cint[0]
  ccall((:getres, "libdislin_d.so"), Cvoid, (Ptr{Cint}, Ptr{Cint}), i1, i2)
  return convert(Int64, i1[1]), convert(Int64, i2[1])
end

function getrco(x1::Float64, x2::Float64)
  xp1 = Cdouble[0]
  xp2 = Cdouble[0]
  ccall((:getrco, "libdislin_d.so"), Cvoid, (Float64, Float64, 
          Ptr{Cdouble}, Ptr{Cdouble}), x1, x2, xp1, xp2)
  return xp1[1], xp2[1]
end

function getrgb()
  x1 = Cdouble[0]
  x2 = Cdouble[0]
  x3 = Cdouble[0]
  ccall((:getrgb, "libdislin_d.so"), Cvoid, (Ptr{Cdouble}, Ptr{Cdouble}, 
          Ptr{Cdouble}), x1, x2, x3)
  return x1[1], x2[1], x3[1]
end

function getscl()
  i1 = Cint[0]
  i2 = Cint[0]
  i3 = Cint[0]
  ccall((:getscl, "libdislin_d.so"), Cvoid, (Ptr{Cint}, Ptr{Cint}, Ptr{Cint}), 
           i1, i2, i3)
  return convert(Int64, i1[1]), convert(Int64, i2[1]), convert(Int64, i3[1])
end

function getscm()
  i1 = Cint[0]
  i2 = Cint[0]
  i3 = Cint[0]
  ccall((:getscm, "libdislin_d.so"), Cvoid, (Ptr{Cint}, Ptr{Cint}, Ptr{Cint}), 
           i1, i2, i3)
  return convert(Int64, i1[1]), convert(Int64, i2[1]), convert(Int64, i3[1])
end

function getscr()
  i1 = Cint[0]
  i2 = Cint[0]
  ccall((:getscr, "libdislin_d.so"), Cvoid, (Ptr{Cint}, Ptr{Cint}), i1, i2)
  return convert(Int64, i1[1]), convert(Int64, i2[1])
end

function getshf(s::String)
  p = ccall((:getshf, "libdislin_d.so"), Cstring, (Ptr{UInt8}, ), s)
  return bytestring(p)
end

function getsp1()
  i1 = Cint[0]
  i2 = Cint[0]
  i3 = Cint[0]
  ccall((:getsp1, "libdislin_d.so"), Cvoid, (Ptr{Cint}, Ptr{Cint}, Ptr{Cint}), 
           i1, i2, i3)
  return convert(Int64, i1[1]), convert(Int64, i2[1]), convert(Int64, i3[1])
end

function getsp2()
  i1 = Cint[0]
  i2 = Cint[0]
  i3 = Cint[0]
  ccall((:getsp2, "libdislin_d.so"), Cvoid, (Ptr{Cint}, Ptr{Cint}, Ptr{Cint}), 
           i1, i2, i3)
  return convert(Int64, i1[1]), convert(Int64, i2[1]), convert(Int64, i3[1])
end

function getsym()
  i1 = Cint[0]
  i2 = Cint[0]
  ccall((:getsym, "libdislin_d.so"), Cvoid, (Ptr{Cint}, Ptr{Cint}), i1, i2)
  return convert(Int64, i1[1]), convert(Int64, i2[1])
end

function gettcl()
  i1 = Cint[0]
  i2 = Cint[0]
  ccall((:gettcl, "libdislin_d.so"), Cvoid, (Ptr{Cint}, Ptr{Cint}), i1, i2)
  return convert(Int64, i1[1]), convert(Int64, i2[1])
end

function gettic()
  i1 = Cint[0]
  i2 = Cint[0]
  i3 = Cint[0]
  ccall((:gettic, "libdislin_d.so"), Cvoid, (Ptr{Cint}, Ptr{Cint}, Ptr{Cint}), 
           i1, i2, i3)
  return convert(Int64, i1[1]), convert(Int64, i2[1]), convert(Int64, i3[1])
end

function gettyp()
  n = ccall((:gettyp, "libdislin_d.so"), Int32, ())
  return convert(Int64, n)
end

function getuni()
  p = ccall((:getuni, "libdislin_d.so"), Cstring, ())
  if (p == C_NULL)
    return convert(Int64, 0)
  end
end

function getver()
  x = ccall((:getver, "libdislin_d.so"), Float64, ())
  return x
end

function getvk()
  i1 = Cint[0]
  i2 = Cint[0]
  i3 = Cint[0]
  ccall((:getvk, "libdislin_d.so"), Cvoid, (Ptr{Cint}, Ptr{Cint}, Ptr{Cint}), 
           i1, i2, i3)
  return convert(Int64, i1[1]), convert(Int64, i2[1]), convert(Int64, i3[1])
end

function getvlt()
  p = ccall((:getvlt, "libdislin_d.so"), Cstring, ())
  return bytestring(p)
end

function getwid()
  n = ccall((:getwid, "libdislin_d.so"), Int32, ())
  return convert(Int64, n)
end

function getwin()
  i1 = Cint[0]
  i2 = Cint[0]
  i3 = Cint[0]
  i4 = Cint[0]
  ccall((:getwin, "libdislin_d.so"), Cvoid, (Ptr{Cint}, Ptr{Cint}, Ptr{Cint},
           Ptr{Cint}), i1, i2, i3, i4)
  return convert(Int64, i1[1]), convert(Int64, i2[1]), convert(Int64, i3[1]),
         convert(Int64, i4[1])
end

function getxid(s::String)
  n = ccall((:getxid, "libdislin_d.so"), Int32, (Ptr{UInt8}, ), s)
  return convert(Int64, n)
end

function gifmod(s1::String, s2::String)
  ccall((:gifmod, "libdislin_d.so"), Cvoid, (Ptr{UInt8}, Ptr{UInt8}), s1, s2)
end

function gmxalf(s::String)
  s1 = Array{UInt8}(undef, 2);
  s2 = Array{UInt8}(undef, 2);
  n = ccall((:gmxalf, "libdislin_d.so"), Int32, (Ptr{UInt8}, Ptr{UInt8},
          Ptr{UInt8}), s, s1, s2)
  n1 = ccall((:trmlen, "libdislin_d.so"), Int32, (Ptr{UInt8}, ), s1)
  n2 = ccall((:trmlen, "libdislin_d.so"), Int32, (Ptr{UInt8}, ), s2)
  resize!(s1, n1)
  resize!(s2, n2)
  GC.@preserve s1
  GC.@preserve s2
  return unsafe_string(pointer(s1)), unsafe_string(pointer(s2))
end

function gothic()
  ccall((:gothic, "libdislin_d.so"), Cvoid, ())
end

function grace(i::Int64)
  ccall((:grace, "libdislin_d.so"), Cvoid, (Int32,), i)
end

function graf(x1::Float64, x2::Float64, x3::Float64, x4::Float64,
              x5::Float64, x6::Float64, x7::Float64, x8::Float64)
  ccall((:graf, "libdislin_d.so"), Cvoid, (Float64, Float64, Float64,
          Float64, Float64, Float64, Float64, Float64), 
          x1, x2, x3, x4, x5, x6, x7, x8)
end

function graf3(x1::Float64, x2::Float64, x3::Float64, x4::Float64,
               x5::Float64, x6::Float64, x7::Float64, x8::Float64,
               x9::Float64, x10::Float64, x11::Float64, x12::Float64)
  ccall((:graf3, "libdislin_d.so"), Cvoid, (Float64, Float64, Float64,
          Float64, Float64, Float64, Float64, Float64, Float64, Float64,
          Float64, Float64),
           x1, x2, x3, x4, x5, x6, x7, x8, x9, x10, x11, x12)
end

function graf3d(x1::Float64, x2::Float64, x3::Float64, x4::Float64,
               x5::Float64, x6::Float64, x7::Float64, x8::Float64,
               x9::Float64, x10::Float64, x11::Float64, x12::Float64)
  ccall((:graf3d, "libdislin_d.so"), Cvoid, (Float64, Float64, Float64,
          Float64, Float64, Float64, Float64, Float64, Float64, Float64,
          Float64, Float64),
           x1, x2, x3, x4, x5, x6, x7, x8, x9, x10, x11, x12)
end

function grafmp(x1::Float64, x2::Float64, x3::Float64, x4::Float64,
                x5::Float64, x6::Float64, x7::Float64, x8::Float64)
  ccall((:grafmp, "libdislin_d.so"), Cvoid, (Float64, Float64, Float64,
          Float64, Float64, Float64, Float64, Float64), 
          x1, x2, x3, x4, x5, x6, x7, x8)
end

function grafp(x1::Float64, x2::Float64, x3::Float64, x4::Float64,
                x5::Float64)
  ccall((:grafp, "libdislin_d.so"), Cvoid, (Float64, Float64, Float64,
          Float64, Float64), x1, x2, x3, x4, x5)
end

function grafr(xray::Vector{Float64}, n::Int64, yray::Vector{Float64}, 
               m::Int64)
  ccall((:grafr, "libdislin_d.so"), Cvoid, 
          (Ptr{Float64}, Int32, Ptr{Float64}, Int32), xray, n, yray, m)
end

function grdpol(i1::Int64, i2::Int64)
  ccall((:grdpol, "libdislin_d.so"), Cvoid, (Int32, Int32), i1, i2)
end

function grffin()
  ccall((:grffin, "libdislin_d.so"), Cvoid, ())
end

function grfimg(s::String)
  ccall((:grfimg, "libdislin_d.so"), Cvoid, (Ptr{UInt8},), s)
end

function grfini(x1::Float64, x2::Float64, x3::Float64, x4::Float64,
           x5::Float64, x6::Float64, x7::Float64, x8::Float64, x9::Float64)
  ccall((:grfini, "libdislin_d.so"), Cvoid, (Float64, Float64, Float64,
          Float64, Float64, Float64, Float64, Float64, Float64), 
          x1, x2, x3, x4, x5, x6, x7, x8, x9)
end

function grid(i1::Int64, i2::Int64)
  ccall((:grid, "libdislin_d.so"), Cvoid, (Int32, Int32), i1, i2)
end

function grid3d(i1::Int64, i2::Int64, s::String)
  ccall((:grid3d, "libdislin_d.so"), Cvoid, (Int32, Int32, Ptr{UInt8}), 
           i1, i2, s)
end

function gridim(x1::Float64, x2::Float64, x3::Float64, i::Int64)
  ccall((:gridim, "libdislin_d.so"), Cvoid, (Float64, Float64, Float64,
          Int32), x1, x2, x3, i)
end

function gridmp(i1::Int64, i2::Int64)
  ccall((:gridmp, "libdislin_d.so"), Cvoid, (Int32, Int32), i1, i2)
end

function gridre(x1::Float64, x2::Float64, x3::Float64, i::Int64)
  ccall((:gridre, "libdislin_d.so"), Cvoid, (Float64, Float64, Float64,
          Int32), x1, x2, x3, i)
end

function gwgatt(i::Int64, s::String)
  n = ccall((:gwgatt, "libdislin_d.so"), Int32, (Int32, Ptr{UInt8}), i, s)
  return convert(Int64, n)
end

function gwgbox(i::Int64)
  n = ccall((:gwgbox, "libdislin_d.so"), Int32, (Int32,), i)
  return convert(Int64, n)
end

function gwgbut(i::Int64)
  n = ccall((:gwgbut, "libdislin_d.so"), Int32, (Int32,), i)
  return convert(Int64, n)
end

function gwgfil(i::Int64)
  s = Array{UInt8}(undef, 257)
  ccall((:gwgfil, "libdislin_d.so"), Cvoid, (Int32, Ptr{UInt8}), i, s)
  n = ccall((:trmlen, "libdislin_d.so"), Int32, (Ptr{UInt8}, ), s)
  resize!(s, n)
  GC.@preserve s
  return unsafe_string(pointer(s))
end

function gwgflt(i::Int64)
  x = ccall((:gwgflt, "libdislin_d.so"), Float64, (Int32,), i)
  return x
end

function gwggui()
  n = ccall((:gwggui, "libdislin_d.so"), Int32, ())
  return convert(Int64, n)
end

function gwgint(i::Int64)
  n = ccall((:gwgint, "libdislin_d.so"), Int32, (Int32,), i)
  return convert(Int64, n)
end

function gwglis(i::Int64)
  n = ccall((:gwglis, "libdislin_d.so"), Int32, (Int32,), i)
  return convert(Int64, n)
end

function gwgscl(i::Int64)
  x = ccall((:gwgscl, "libdislin_d.so"), Float64, (Int32,), i)
  return x
end

function gwgsiz(i::Int64)
  i1 = Cint[0]
  i2 = Cint[0]
  ccall((:gwgsiz, "libdislin_d.so"), Cvoid, (Int32, Ptr{Cint}, Ptr{Cint}), 
          i, i1, i2)
  return convert(Int64, i1[1]), convert(Int64, i2[1])
end

function gwgtbf(i1::Int64, i2::Int64, i3::Int64)
  x = ccall((:gwgtbf, "libdislin_d.so"), Float64, (Int32, Int32, Int32), 
               i1, i2, i3)
  return x
end

function gwgtbi(i1::Int64, i2::Int64, i3::Int64)
  n = ccall((:gwgtbi, "libdislin_d.so"), Int32, (Int32, Int32, Int32), 
               i1, i2, i3)
  return convert(Int64, n)
end

function gwgtbl(i1::Int64, xray::Vector{Float64}, i2::Int64, i3::Int64,
                s::String)
  ccall((:gwgtbl, "libdislin_d.so"), Cvoid, 
          (Int32, Ptr{Float64}, Int32, Int32, Ptr{UInt8}), i1, xray, i2, i3, s)
end

function gwgtbs(i1::Int64, i2::Int64, i3::Int64)
  s = Array{UInt8}(undef, 257)
  ccall((:gwgtbs, "libdislin_d.so"), Cvoid, (Int32, Int32, Int32, Ptr{UInt8}),
          i1, i2, i3, s)
  n = ccall((:trmlen, "libdislin_d.so"), Int32, (Ptr{UInt8}, ), s)
  resize!(s, n)
  GC.@preserve s
  return unsafe_string(pointer(s))
end

function gwgtxt(i::Int64)
  s = Array{UInt8}(undef, 257)
  ccall((:gwgtxt, "libdislin_d.so"), Cvoid, (Int32, Ptr{UInt8}), i, s)
  n = ccall((:trmlen, "libdislin_d.so"), Int32, (Ptr{UInt8}, ), s)
  resize!(s, n)
  GC.@preserve s
  return unsafe_string(pointer(s))
end

function gwgxid(i::Int64)
  n = ccall((:gwgxid, "libdislin_d.so"), Int32, (Int32,), i)
  return convert(Int64, n)
end

function height(i::Int64)
  ccall((:height, "libdislin_d.so"), Cvoid, (Int32,), i)
end

function helve()
  ccall((:helve, "libdislin_d.so"), Cvoid, ())
end

function helves()
  ccall((:helves, "libdislin_d.so"), Cvoid, ())
end

function helvet()
  ccall((:helvet, "libdislin_d.so"), Cvoid, ())
end

function hidwin(i::Int64, s::String)
  ccall((:hidwin, "libdislin_d.so"), Cvoid, (Int32, Ptr{UInt8}), i, s)
end

function histog(xray::Vector{Float64}, n::Int64, x::Vector{Float64},
                y::Vector{Float64})
  m = Cint[0]
  ccall((:histog, "libdislin_d.so"), Cvoid, 
          (Ptr{Float64}, Int32, Ptr{Float64}, Ptr{Float64}, Ptr{Cint}), 
          xray, n, x, y, m)
  return convert(Int64, m[1])
end

function hname(i::Int64)
  ccall((:hname, "libdislin_d.so"), Cvoid, (Int32,), i)
end

function hpgmod(s1::String, s2::String)
  ccall((:hpgmod, "libdislin_d.so"), Cvoid, (Ptr{UInt8}, Ptr{UInt8}), s1, s2)
end

function hsvrgb(x1::Float64, x2::Float64, x3::Float64)
  xp1 = Cdouble[0]
  xp2 = Cdouble[0]
  xp3 = Cdouble[0]
  ccall((:hsvrgb, "libdislin_d.so"), Cvoid, (Float64, Float64, Float64,
          Ptr{Cdouble}, Ptr{Cdouble}, Ptr{Cdouble}), x1, x2, x3, xp1, xp2, xp3)
  return xp1[1], xp2[1], xp3[1]
end

function hsym3d(x::Float64)
  ccall((:hsym3d, "libdislin_d.so"), Cvoid, (Float64,), x)
end

function hsymbl(i::Int64)
  ccall((:hsymbl, "libdislin_d.so"), Cvoid, (Int32,), i)
end

function htitle(i::Int64)
  ccall((:htitle, "libdislin_d.so"), Cvoid, (Int32,), i)
end

function hwfont()
  ccall((:hwfont, "libdislin_d.so"), Cvoid, ())
end

function hwmode(s1::String, s2::String)
  ccall((:hwmode, "libdislin_d.so"), Cvoid, (Ptr{UInt8}, Ptr{UInt8}), s1, s2)
end

function hworig(i1::Int64, i2::Int64)
  ccall((:hworig, "libdislin_d.so"), Cvoid, (Int32, Int32), i1, i2)
end

function hwpage(i1::Int64, i2::Int64)
  ccall((:hwpage, "libdislin_d.so"), Cvoid, (Int32, Int32), i1, i2)
end

function hwscal(x::Float64)
  ccall((:hwscal, "libdislin_d.so"), Cvoid, (Float64,), x)
end

function imgbox(i1::Int64, i2::Int64, i3::Int64, i4::Int64)
  ccall((:imgbox, "libdislin_d.so"), Cvoid, (Int32, Int32, Int32, Int32), 
           i1, i2, i3, i4)
end

function imgwin(i1::Int64, i2::Int64, i3::Int64, i4::Int64)
  ccall((:imgwin, "libdislin_d.so"), Cvoid, (Int32, Int32, Int32, Int32), 
           i1, i2, i3, i4)
end

function imgfin()
  ccall((:imgfin, "libdislin_d.so"), Cvoid, ())
end

function imgfmt(s::String)
  ccall((:imgfmt, "libdislin_d.so"), Cvoid, (Ptr{UInt8},), s)
end

function imgini()
  ccall((:imgini, "libdislin_d.so"), Cvoid, ())
end

function imgmod(s::String)
  ccall((:imgmod, "libdislin_d.so"), Cvoid, (Ptr{UInt8},), s)
end

function imgsiz(i1::Int64, i2::Int64)
  ccall((:imgsiz, "libdislin_d.so"), Cvoid, (Int32, Int32), i1, i2)
end

function imgptr(i::Int64)
  ccall((:imgptr, "libdislin_d.so"), Cvoid, (Int32,), i)
end

function inccrv(i::Int64)
  ccall((:inccrv, "libdislin_d.so"), Cvoid, (Int32,), i)
end

function incdat(i1::Int64, i2::Int64, i3::Int64)
  n = ccall((:inccrv, "libdislin_d.so"), Cvoid, (Int32, Int32, Int32), 
              i1, i2, i3)
  return convert(Int64, n)
end

function incfil(s::String)
  ccall((:incfil, "libdislin_d.so"), Cvoid, (Ptr{UInt8},), s)
end

function incmrk(i::Int64)
  ccall((:incmrk, "libdislin_d.so"), Cvoid, (Int32,), i)
end

function indrgb(x1::Float64, x2::Float64, x3::Float64)
  n = ccall((:indrgb, "libdislin_d.so"), Cvoid, (Float64, Float64, Float64), 
              x1, x2, x3)
  return convert(Int64, n)
end

function intax()
  ccall((:intax, "libdislin_d.so"), Cvoid, ())
end

function intcha(i::Int64)
  s = Array{UInt8}(undef, 80)
  n = ccall((:intcha, "libdislin_d.so"), Int32, (Int32, Ptr{UInt8}), 
              i, s)
  n = ccall((:trmlen, "libdislin_d.so"), Int32, (Ptr{UInt8}, ), s)
  resize!(s, n)
  GC.@preserve s
  return unsafe_string(pointer(s))
end

function intlen(i::Int64)
  n = ccall((:intlen, "libdislin_d.so"), Cvoid, (Int32, ), i)
  return convert(Int64, n)
end

function intrgb(x1::Float64, x2::Float64, x3::Float64)
  n = ccall((:intrgb, "libdislin_d.so"), Int32, (Float64, Float64, Float64), 
              x1, x2, x3)
  return convert(Int64, n)
end

function intutf(iray::Vector{Int32}, n::Int64)
  s = Array{UInt8}(undef, n * 4 + 1)
  ccall((:intutf, "libdislin_d.so"), Cvoid, 
         (Ptr{Int32}, Int32, Ptr{UInt8}, Int32), iray, n, s, n * 4)
  m = ccall((:trmlen, "libdislin_d.so"), Int32, (Ptr{UInt8}, ), s)
  resize!(s, m)
  GC.@preserve s
  return unsafe_string(pointer(s))
end

function isopts(xray::Vector{Float64}, nx::Int64, yray::Vector{Float64},
                ny::Int64, zray::Vector{Float64}, nz::Int64, 
                wmat::Array{Float64, 3}, wlev::Float64,
                xtri::Vector{Float64}, ytri::Vector{Float64},
                ztri::Vector{Float64}, nmax::Int64)
  w = transpose(wmat)
  ntri = Cint[0]

  n = ccall((:isopts, "libdislin_d.so"), Cvoid, (Ptr{Float64}, Int32, 
          Ptr{Float64}, Int32, Ptr{Float64}, Int32, Ptr{Float64}, Float64,
          Ptr{Float64}, Ptr{Float64}, Ptr{Float64}, Int32, Ptr{Cint}), 
          xray, nx, yray, ny, zray, nz, w, wlev, xtri, ytri, ztri, nmax, nzti)
  w = 0
  return convert(Int64, ntri[1])
end

function itmcat(s1::String, s2::String)
  n1 = ccall((:trmlen, "libdislin_d.so"), Int32, (Ptr{UInt8}, ), s1)
  n2 = ccall((:trmlen, "libdislin_d.so"), Int32, (Ptr{UInt8}, ), s2)
  s = Array{UInt8}(undef, n1 + n2 + 2)
  for i = 1:n1
    s[i] = s1[i]
  end
  s[n1+1] = 0
  ccall((:itmcat, "libdislin_d.so"), Cvoid, (Ptr{UInt8}, Ptr{UInt8}), s, s2)
  GC.@preserve s
  return unsafe_string(pointer(s))
end

function itmcnt(s::String)
  n = ccall((:itmcnt, "libdislin_d.so"), Int32, (Ptr{UInt8},), s)
  return convert(Int64, n)
end

function itmncat(s1::String, nmax::Int64, s2::String)
  n1 = ccall((:trmlen, "libdislin_d.so"), Int32, (Ptr{UInt8}, ), s1)
  n2 = ccall((:trmlen, "libdislin_d.so"), Int32, (Ptr{UInt8}, ), s2)
  s = Array{UInt8}(undef, n1 + n2 + 2)
  for i = 1:n1
    s[i] = s1[i]
  end
  s[n1+1] = 0
  ccall((:itmncat, "libdislin_d.so"), Cvoid, (Ptr{UInt8}, Int32, Ptr{UInt8}), 
          s, nmax, s2)
  GC.@preserve s
  return unsafe_string(pointer(s))
end

function itmstr(s::String, i::Int64)
  p = ccall((:itmstr, "libdislin_d.so"), Cstring, (Ptr{UInt8}, Int32), s, i)
  val = bytestring(p)
  ccall((:freeptr, "libdislin_d.so"), Cvoid, (Cstring, ), p)
  return val
end

function jusbar(s::String)
  ccall((:jusbar, "libdislin_d.so"), Cvoid, (Ptr{UInt8},), s)
end

function labclr(i::Int64, s::String)
  ccall((:labclr, "libdislin_d.so"), Cvoid, (Int32, Ptr{UInt8}), i, s)
end

function labdig(i::Int64, s::String)
  ccall((:labdig, "libdislin_d.so"), Cvoid, (Int32, Ptr{UInt8}), i, s)
end

function labdis(i::Int64, s::String)
  ccall((:labdis, "libdislin_d.so"), Cvoid, (Int32, Ptr{UInt8}), i, s)
end

function labels(s1::String, s2::String)
  ccall((:labels, "libdislin_d.so"), Cvoid, (Ptr{UInt8}, Ptr{UInt8}), s1, s2)
end

function labjus(s1::String, s2::String)
  ccall((:labjus, "libdislin_d.so"), Cvoid, (Ptr{UInt8}, Ptr{UInt8}), s1, s2)
end

function labl3d(s::String)
  ccall((:labl3d, "libdislin_d.so"), Cvoid, (Ptr{UInt8},), s)
end

function labmod(s1::String, s2::String, s3::String)
  ccall((:labmod, "libdislin_d.so"), Cvoid, (Ptr{UInt8}, Ptr{UInt8}, Ptr{UInt8}),
           s1, s2, s3)
end

function labpos(s1::String, s2::String)
  ccall((:labpos, "libdislin_d.so"), Cvoid, (Ptr{UInt8}, Ptr{UInt8}), s1, s2)
end

function labtyp(s1::String, s2::String)
  ccall((:labtyp, "libdislin_d.so"), Cvoid, (Ptr{UInt8}, Ptr{UInt8}), s1, s2)
end

function ldimg(s::String, iray::Vector{UInt16}, i1::Int64, i2::Int64)
  ccall((:ldimg, "libdislin_d.so"), Cvoid, (Ptr{UInt8}, Ptr{UInt16}, Int32,
          Int32), s, iray, i1, i2)
end

function legbgd(i::Int64)
  ccall((:legbgd, "libdislin_d.so"), Cvoid, (Int32,), i)
end

function legclr()
  ccall((:legclr, "libdislin_d.so"), Cvoid, ())
end

function legend(cbuf::Vector{UInt8}, i::Int64)
  ccall((:legend, "libdislin_d.so"), Cvoid, (Ptr{UInt8}, Int32), cbuf, i)
end

function legini(cbuf::Vector{UInt8}, i1::Int64, i2::Int64)
  ccall((:legini, "libdislin_d.so"), Cvoid, (Ptr{UInt8}, Int32, Int32), 
           cbuf, i1, i2)
end

function leglin(cbuf::Vector{UInt8}, s::String, i::Int64)
  ccall((:leglin, "libdislin_d.so"), Cvoid, (Ptr{UInt8}, Ptr{UInt8}, Int32), 
           cbuf, s, i)
end

function legopt(x1::Float64, x2::Float64, x3::Float64)
  ccall((:legopt, "libdislin_d.so"), Cvoid, (Float64, Float64, Float64), 
          x1, x2, x3)
end

function legpat(i1::Int64, i2::Int64, i3::Int64, 
                i4::Int64, i5::Int64, i6::Int64)
  ccall((:legpat, "libdislin_d.so"), Cvoid, (Int32, Int32, Int32, Int32, Int32, 
          Int32), i1, i2, i3, i4, i5, i6)
end

function legpos(i1::Int64, i2::Int64)
  ccall((:legpos, "libdislin_d.so"), Cvoid, (Int32, Int32), i1, i2)
end

function legsel(nray::Vector{Int32}, n::Int64)
  ccall((:legsel, "libdislin_d.so"), Cvoid, (Ptr{Int32}, Int32), nray, n)
end

function legtbl(i::Int64, s::String)
  ccall((:legtbl, "libdislin_d.so"), Cvoid, (Int32, Ptr{UInt8}), i, s)
end

function legtit(s::String)
  ccall((:legtit, "libdislin_d.so"), Cvoid, (Ptr{UInt8},), s)
end

function legtyp(s::String)
  ccall((:legtyp, "libdislin_d.so"), Cvoid, (Ptr{UInt8},), s)
end

function legval(x::Float64, s::String)
  ccall((:legval, "libdislin_d.so"), Cvoid, (Float64, Ptr{UInt8}), x, s)
end

function lfttit()
  ccall((:lfttit, "libdislin_d.so"), Cvoid, ())
end

function licmod(s1::String, s2::String)
  ccall((:licmod, "libdislin_d.so"), Cvoid, (Ptr{UInt8}, Ptr{UInt8}), s1, s2)
end

function licpts(xv::Vector{Float64}, yv::Vector{Float64}, nx::Int64,
                ny::Int64, itmat::Array{Int32, 2}, wmat::Array{Float64, 2})
  imat = Array{Int32}(undef, nx, ny)
  xmat = Array{Float64}(undef, nx, ny)
  ccall((:licpts, "libdislin_d.so"), Cvoid, (Ptr{Float64}, Ptr{Float64}, Int32, 
          Int32, Ptr{Int32}, Ptr{Float64}), xv, yv, nx, ny, imat, xmat)
  transpose!(itmat, imat)
  transpose!(wmat, xmat)
  imat = 0
  xmat = 0
end

function light(s::String)
  ccall((:light, "libdislin_d.so"), Cvoid, (Ptr{UInt8},), s)
end

function linclr(nray::Vector{Int32}, n::Int64)
  ccall((:linclr, "libdislin_d.so"), Cvoid, (Ptr{Int32}, Int32), nray, n)
end

function lincyc(i1::Int64, i2::Int64)
  ccall((:lincyc, "libdislin_d.so"), Cvoid, (Int32, Int32), i1, i2)
end

function line(i1::Int64, i2::Int64, i3::Int64, i4::Int64)
  ccall((:line, "libdislin_d.so"), Cvoid, (Int32, Int32, Int32, Int32), 
           i1, i2, i3, i4)
end

function linesp(x::Float64)
  ccall((:linesp, "libdislin_d.so"), Cvoid, (Float64,), x)
end

function linfit(xray::Vector{Float64}, yray::Vector{Float64}, n::Int64,
  s1::String)
  a = Cdouble[0]
  b = Cdouble[0]
  r = Cdouble[0]
  ccall((:linfit, "libdislin_d.so"), Cvoid, (Ptr{Float64}, Ptr{Float64}, Int32,
       Ptr{Cdouble}, Ptr{Cdouble}, Ptr{Cdouble}, Ptr{UInt8}), xray, yray, n, 
       a, b , r, s1);
  return a[1], b[1], r[1]
end

function linmod(s1::String, s2::String)
  ccall((:linmod, "libdislin_d.so"), Cvoid, (Ptr{UInt8}, Ptr{UInt8}), s1, s2)
end

function lintyp(i::Int64)
  ccall((:lintyp, "libdislin_d.so"), Cvoid, (Int32,), i)
end

function linwid(i::Int64)
  ccall((:linwid, "libdislin_d.so"), Cvoid, (Int32,), i)
end

function litmod(i::Int64, s::String)
  ccall((:litmod, "libdislin_d.so"), Cvoid, (Int32, Ptr{UInt8}), i, s)
end

function litop3(i::Int64, x1::Float64, x2::Float64, x3::Float64, 
                s::String)
  ccall((:litop3, "libdislin_d.so"), Cvoid, (Int32, Float64, Float64, Float64, 
          Ptr{UInt8}), i, x1, x2, x3, s)
end

function litopt(i::Int64, x::Float64, s::String)
  ccall((:litopt, "libdislin_d.so"), Cvoid, (Int32, Float64, Ptr{UInt8}), 
          i, x, s)
end

function litpos(i::Int64, x1::Float64, x2::Float64, x3::Float64, 
                s::String)
  ccall((:litpos, "libdislin_d.so"), Cvoid, (Int32, Float64, Float64, Float64, 
          Ptr{UInt8}), i, x1, x2, x3, s)
end

function lncap(s::String)
  ccall((:lncap, "libdislin_d.so"), Cvoid, (Ptr{UInt8},), s)
end

function lnjoin(s::String)
  ccall((:lnjoin, "libdislin_d.so"), Cvoid, (Ptr{UInt8},), s)
end

function lnmlt(x::Float64)
  ccall((:lnmlt, "libdislin_d.so"), Cvoid, (Float64,), x)
end

function logtic(s::String)
  ccall((:logtic, "libdislin_d.so"), Cvoid, (Ptr{UInt8},), s)
end

function mapbas(s::String)
  ccall((:mapbas, "libdislin_d.so"), Cvoid, (Ptr{UInt8},), s)
end

function mapfil(s1::String, s2::String)
  ccall((:mapfil, "libdislin_d.so"), Cvoid, (Ptr{UInt8}, Ptr{UInt8}), s1, s2)
end

function mapimg(s::String, x1::Float64, x2::Float64, x3::Float64,
                x4::Float64, x5::Float64, x6::Float64)
  ccall((:mapimg, "libdislin_d.so"), Cvoid, (Ptr{UInt8}, Float64, Float64,
          Float64, Float64, Float64, Float64), s, x1, x2, x3, x4, x5, x6)
end

function maplab(s1::String, s2::String)
  ccall((:maplab, "libdislin_d.so"), Cvoid, (Ptr{UInt8}, Ptr{UInt8}), s1, s2)
end

function maplev(s::String)
  ccall((:maplev, "libdislin_d.so"), Cvoid, (Ptr{UInt8},), s)
end

function mapmod(s::String)
  ccall((:mapmod, "libdislin_d.so"), Cvoid, (Ptr{UInt8},), s)
end

function mappol(x1::Float64, x2::Float64)
  ccall((:mappol, "libdislin_d.so"), Cvoid, (Float64, Float64), x1, x2)
end

function mapopt(s1::String, s2::String)
  ccall((:mapopt, "libdislin_d.so"), Cvoid, (Ptr{UInt8}, Ptr{UInt8}), s1, s2)
end

function mapref(x1::Float64, x2::Float64)
  ccall((:mapref, "libdislin_d.so"), Cvoid, (Float64, Float64), x1, x2)
end

function mapsph(x::Float64)
  ccall((:mapsph, "libdislin_d.so"), Cvoid, (Float64,), x)
end

function marker(i::Int64)
  ccall((:marker, "libdislin_d.so"), Cvoid, (Int32,), i)
end

function matop3(x1::Float64, x2::Float64, x3::Float64, s::String)
  ccall((:matop3, "libdislin_d.so"), Cvoid, (Float64, Float64, Float64, 
          Ptr{UInt8}), x1, x2, x3, s)
end

function matopt(x::Float64, s::String)
  ccall((:matopt, "libdislin_d.so"), Cvoid, (Float64, Ptr{UInt8}), x, s)
end

function mdfmat(i1::Int64, i2::Int64, x::Float64)
  ccall((:mdfmat, "libdislin_d.so"), Cvoid, (Int32, Int32, Float64), i1, i2, x)
end

function messag(s::String, i1::Int64, i2::Int64)
  ccall((:messag, "libdislin_d.so"), Cvoid, (Ptr{UInt8}, Int32, Int32), 
          s, i1, i2)
end

function metafl(s::String)
  ccall((:metafl, "libdislin_d.so"), Cvoid, (Ptr{UInt8},), s)
end

function mixalf()
  ccall((:mixalf, "libdislin_d.so"), Cvoid, ())
end

function mixleg()
  ccall((:mixleg, "libdislin_d.so"), Cvoid, ())
end

function mpaepl(i::Int64)
  ccall((:mpaepl, "libdislin_d.so"), Cvoid, (Int32,), i)
end

function mplang(x::Float64)
  ccall((:mplang, "libdislin_d.so"), Cvoid, (Float64,), x)
end

function mplclr(i1::Int64, i2::Int64)
  ccall((:mplclr, "libdislin_d.so"), Cvoid, (Int32, Int32), i1, i2)
end

function mplpos(i1::Int64, i2::Int64)
  ccall((:mplpos, "libdislin_d.so"), Cvoid, (Int32, Int32), i1, i2)
end

function mplsiz(i::Int64)
  ccall((:mplsiz, "libdislin_d.so"), Cvoid, (Int32,), i)
end

function mpslogo(i1::Int64, i2::Int64, i3::Int64, s::String)
  ccall((:mpslogo, "libdislin_d.so"), Cvoid, (Int32, Int32, Int32, Ptr{UInt8}),
          i1, i2, i3, s)
end

function mrkclr(i::Int64)
  ccall((:mrkclr, "libdislin_d.so"), Cvoid, (Int32,), i)
end

function msgbox(s::String)
  ccall((:msgbox, "libdislin_d.so"), Cvoid, (Ptr{UInt8},), s)
end

function mshclr(i::Int64)
  ccall((:mshclr, "libdislin_d.so"), Cvoid, (Int32,), i)
end

function mshcrv(i::Int64)
  ccall((:mshcrv, "libdislin_d.so"), Cvoid, (Int32,), i)
end

function mylab(s1::String, i::Int64, s2::String)
  ccall((:mylab, "libdislin_d.so"), Cvoid, (Ptr{UInt8}, Int32, Ptr{UInt8}), 
          s1, i, s2)
end

function myline(nray::Vector{Int32}, n::Int64)
  ccall((:myline, "libdislin_d.so"), Cvoid, (Ptr{Int32}, Int32), nray, n)
end

function mypat(i1::Int64, i2::Int64, i3::Int64, i4::Int64)
  ccall((:mypat, "libdislin_d.so"), Cvoid, (Int32, Int32, Int32, Int32), 
           i1, i2, i3, i4)
end

function mysymb(xray::Vector{Float64}, yray::Vector{Float64}, n::Int64,
               isym::Int64, iflag::Int64)
  ccall((:mysymb, "libdislin_d.so"), Cvoid, 
          (Ptr{Float64}, Ptr{Float64}, Int32, Int32, Int32), xray, yray, n,
          isym, iflag)
end

function myvlt(xray::Vector{Float64}, yray::Vector{Float64}, 
                zray::Vector{Float64}, n::Int64)
  ccall((:myvlt, "libdislin_d.so"), Cvoid, (Ptr{Float64}, Ptr{Float64}, 
          Ptr{Float64}, Int32), xray, yray, zray, n)
end

function namdis(i::Int64, s::String)
  ccall((:namdis, "libdislin_d.so"), Cvoid, (Int32, Ptr{UInt8}), i, s)
end

function name(s1::String, s2::String)
  ccall((:name, "libdislin_d.so"), Cvoid, (Ptr{UInt8}, Ptr{UInt8}), s1, s2)
end

function namjus(s1::String, s2::String)
  ccall((:namjus, "libdislin_d.so"), Cvoid, (Ptr{UInt8}, Ptr{UInt8}), s1, s2)
end

function nancrv(s::String)
  ccall((:nancrv, "libdislin_d.so"), Cvoid, (Ptr{UInt8},), s)
end

function neglog(x::Float64)
  ccall((:neglog, "libdislin_d.so"), Cvoid, (Float64,), x)
end

function newmix()
  ccall((:newmix, "libdislin_d.so"), Cvoid, ())
end

function newpag()
  ccall((:newpag, "libdislin_d.so"), Cvoid, ())
end

function nlmess(s::String)
  n = ccall((:nlmess, "libdislin_d.so"), Int32, (Ptr{UInt8},), s)
  return convert(Int64, n)
end

function nlnumb(x::Float64, i::Int64)
  n = ccall((:nlnumb, "libdislin_d.so"), Int32, (Float64, Int32), x, i)
  return convert(Int64, n)
end

function noarln()
  ccall((:noarln, "libdislin_d.so"), Cvoid, ())
end

function nobar()
  ccall((:nobar, "libdislin_d.so"), Cvoid, ())
end

function nobgd()
  ccall((:nobgd, "libdislin_d.so"), Cvoid, ())
end

function nochek()
  ccall((:nochek, "libdislin_d.so"), Cvoid, ())
end

function noclip()
  ccall((:noclip, "libdislin_d.so"), Cvoid, ())
end

function nofill()
  ccall((:nofill, "libdislin_d.so"), Cvoid, ())
end

function nograf()
  ccall((:nograf, "libdislin_d.so"), Cvoid, ())
end

function nohide()
  ccall((:nohide, "libdislin_d.so"), Cvoid, ())
end

function noline(s::String)
  ccall((:noline, "libdislin_d.so"), Cvoid, (Ptr{UInt8},), s)
end

function number(x::Float64, i1::Int64, i2::Int64, i3::Int64)
  ccall((:number, "libdislin_d.so"), Cvoid, (Float64, Int32, Int32, Int32), 
           x, i1, i2, i3)
end

function numfmt(s::String)
  ccall((:numfmt, "libdislin_d.so"), Cvoid, (Ptr{UInt8},), s)
end

function numode(s1::String, s2::String, s3::String, 
                s4::String)
  ccall((:numode, "libdislin_d.so"), Cvoid, (Ptr{UInt8}, Ptr{UInt8}, Ptr{UInt8},
          Ptr{UInt8}), s1, s2, s3, s4)
end

function nwkday(i1::Int64, i2::Int64, i3::Int64)
  n = ccall((:nwkday, "libdislin_d.so"), Int32, (Int32, Int32, Int32), 
              i1, i2, i3)
  return convert(Int64, n)
end

function nxlegn(cbuf::Vector{UInt8})
  n = ccall((:nxlegn, "libdislin_d.so"), Int32, (Ptr{UInt8},), cbuf)
  return convert(Int64, n)
end

function nxpixl(i1::Int64, i2::Int64)
  n = ccall((:nxpixl, "libdislin_d.so"), Int32, (Int32, Int32), i1, i2)
  return convert(Int64, n)
end

function nxposn(x::Float64)
  n = ccall((:nxposn, "libdislin_d.so"), Int32, (Float64, ), x)
  return convert(Int64, n)
end

function nylegn(cbuf::Vector{UInt8})
  n = ccall((:nylegn, "libdislin_d.so"), Int32, (Ptr{UInt8},), cbuf)
  return convert(Int64, n)
end

function nypixl(i1::Int64, i2::Int64)
  n = ccall((:nypixl, "libdislin_d.so"), Int32, (Int32, Int32), i1, i2)
  return convert(Int64, n)
end

function nyposn(x::Float64)
  n = ccall((:nyposn, "libdislin_d.so"), Int32, (Float64, ), x)
  return convert(Int64, n)
end

function nzposn(x::Float64)
  n = ccall((:nzposn, "libdislin_d.so"), Int32, (Float64, ), x)
  return convert(Int64, n)
end

function openfl(s::String, i1::Int64, i2::Int64)
  n = ccall((:openfl, "libdislin_d.so"), Int32, (Ptr{UInt8}, Int32, Int32),
              s, i1, i2)
  return convert(Int64, n)
end

function opnwin(i::Int64)
  ccall((:opnwin, "libdislin_d.so"), Cvoid, (Int32,), i)
end

function origin(i1::Int64, i2::Int64)
  ccall((:origin, "libdislin_d.so"), Cvoid, (Int32, Int32), i1, i2)
end

function page(i1::Int64, i2::Int64)
  ccall((:page, "libdislin_d.so"), Cvoid, (Int32, Int32), i1, i2)
end

function pagera()
  ccall((:pagera, "libdislin_d.so"), Cvoid, ())
end

function pagfll(i::Int64)
  ccall((:pagfll, "libdislin_d.so"), Cvoid, (Int32,), i)
end

function paghdr(s1::String, s2::String, i1::Int64, i2::Int64)
  ccall((:paghdr, "libdislin_d.so"), Cvoid, (Ptr{UInt8}, Ptr{UInt8}, 
          Int32, Int32), s1, s2, i1, i2)
end

function pagmod(s::String)
  ccall((:pagmod, "libdislin_d.so"), Cvoid, (Ptr{UInt8},), s)
end

function pagorg(s::String)
  ccall((:pagorg, "libdislin_d.so"), Cvoid, (Ptr{UInt8},), s)
end

function pagwin(i1::Int64, i2::Int64)
  ccall((:pagwin, "libdislin_d.so"), Cvoid, (Int32, Int32), i1, i2)
end

function patcyc(i1::Int64, i2::Int64)
  ccall((:patcyc, "libdislin_d.so"), Cvoid, (Int32, Int32), i1, i2)
end

function pdfbuf(iray::Vector{UInt8}, nmax::Int64) 
  n = ccall((:pdfbuf, "libdislin_d.so"), Int32, (Ptr{UInt8}, Int32),
          iray, nmax)
  return convert(Int64, n)
end

function pdfmod(s1::String, s2::String)
  ccall((:pdfmod, "libdislin_d.so"), Cvoid, (Ptr{UInt8}, Ptr{UInt8}), s1, s2)
end

function pdfmrk(s1::String, s2::String)
  ccall((:pdfmrk, "libdislin_d.so"), Cvoid, (Ptr{UInt8}, Ptr{UInt8}), s1, s2)
end

function penwid(x::Float64)
  ccall((:penwid, "libdislin_d.so"), Cvoid, (Float64,), x)
end

function pie(i1::Int64, i2::Int64, i3::Int64, x1::Float64, x2::Float64)
  ccall((:pie, "libdislin_d.so"), Cvoid, (Int32, Int32, Int32, Float64, 
           Float64), i1, i2, i3, x1, x2)
end

function piebor(i::Int64)
  ccall((:piebor, "libdislin_d.so"), Cvoid, (Int32,), i)
end

function pieclr(ic1::Vector{Int32}, ic2::Vector{Int32}, n::Int64)
  ccall((:pieclr, "libdislin_d.so"), Cvoid, 
         (Ptr{Int32}, Ptr{Int32}, Int32), ic1, ic2, n)
end

function pieexp()
  ccall((:pieexp, "libdislin_d.so"), Cvoid, ())
end

function piegrf(cbuf::Vector{UInt8}, i1::Int64, xray::Vector{Float64}, 
                i2::Int64)
  ccall((:piegrf, "libdislin_d.so"), Cvoid, 
          (Ptr{UInt8}, Int32, Ptr{Float64}, Int32), cbuf, i1, xray, i2)
end

function pielab(s1::String, s2::String)
  ccall((:pielab, "libdislin_d.so"), Cvoid, (Ptr{UInt8}, Ptr{UInt8}), s1, s2)
end

function pieopt(x1::Float64, x2::Float64)
  ccall((:pieopt, "libdislin_d.so"), Cvoid, (Float64, Float64), x1, x2)
end

function pierot(x::Float64)
  ccall((:pierot, "libdislin_d.so"), Cvoid, (Float64,), x)
end

function pietyp(s::String)
  ccall((:pietyp, "libdislin_d.so"), Cvoid, (Ptr{UInt8},), s)
end

function pieval(x::Float64, s::String)
  ccall((:pieval, "libdislin_d.so"), Cvoid, (Float64, Ptr{UInt8}), x, s)
end

function pievec(i::Int64, s::String)
  ccall((:pievec, "libdislin_d.so"), Cvoid, (Int32, Ptr{UInt8}), i, s)
end

function pike3d(x1::Float64, x2::Float64, x3::Float64, x4::Float64,
           x5::Float64, x6::Float64, x7::Float64, i1::Int64, i2::Int64)
  ccall((:pike3d, "libdislin_d.so"), Cvoid, (Float64, Float64, Float64,
          Float64, Float64, Float64, Float64, Int32, Int32), 
          x1, x2, x3, x4, x5, x6, x7, i1, i2)
end

function plat3d(x1::Float64, x2::Float64, x3::Float64, x4::Float64, 
                s::String)
  ccall((:plat3d, "libdislin_d.so"), Cvoid, (Float64, Float64, Float64, Float64, 
          Ptr{UInt8}), x1, x2, x3, x4, s)
end

function plyfin(s1::String, s2::String)
  ccall((:plyfin, "libdislin_d.so"), Cvoid, (Ptr{UInt8}, Ptr{UInt8}), s1, s2)
end

function plyini(s::String)
  ccall((:plyini, "libdislin_d.so"), Cvoid, (Ptr{UInt8},), s)
end

function pngmod(s1::String, s2::String)
  ccall((:pngmod, "libdislin_d.so"), Cvoid, (Ptr{UInt8}, Ptr{UInt8}), s1, s2)
end

function point(i1::Int64, i2::Int64, i3::Int64, i4::Int64, i5::Int64)
  ccall((:point, "libdislin_d.so"), Cvoid, (Int32, Int32, Int32, Int32, Int32), 
           i1, i2, i3, i4, i5)
end

function polcrv(s::String)
  ccall((:polcrv, "libdislin_d.so"), Cvoid, (Ptr{UInt8},), s)
end

function polclp(xray::Vector{Float64}, yray::Vector{Float64}, n::Int64,
                xout::Vector{Float64},yout::Vector{Float64}, nmax::Int64,
                xv::Float64, cedge::String)
  ccall((:polclp, "libdislin_d.so"), Cvoid, (Ptr{Float64}, Ptr{Float64}, Int32,
          Ptr{Float64}, Ptr{Float64}, Int32, Float64, Ptr{UInt8}), 
          xray, yray, n, xout, yout, nmax, xv, cedge)
end

function polmod(s1::String, s2::String)
  ccall((:polmod, "libdislin_d.so"), Cvoid, (Ptr{UInt8}, Ptr{UInt8}), s1, s2)
end

function pos2pt(x1::Float64, x2::Float64)
  xp1 = Cdouble[0]
  xp2 = Cdouble[0]
  ccall((:pos2pt, "libdislin_d.so"), Cvoid, (Float64, Float64, 
          Ptr{Cdouble}, Ptr{Cdouble}), x1, x2, xp1, xp2)
  return xp1[1], xp2[1]
end

function pos3pt(x1::Float64, x2::Float64, x3::Float64)
  xp1 = Cdouble[0]
  xp2 = Cdouble[0]
  xp3 = Cdouble[0]
  ccall((:pos3pt, "libdislin_d.so"), Cvoid, (Float64, Float64, Float64,
          Ptr{Cdouble}, Ptr{Cdouble}, Ptr{Cdouble}), x1, x2, x3, xp1, xp2, xp3)
  return xp1[1], xp2[1], xp3[1] 
end

function posbar(s::String)
  ccall((:posbar, "libdislin_d.so"), Cvoid, (Ptr{UInt8},), s)
end

function posifl(i1::Int64, i2::Int64)
  n = ccall((:posifl, "libdislin_d.so"), Int32, (Int32, Int32), i1, i2)
  return convert(Int64, n)
end
 
function proj3d(s::String)
  ccall((:proj3d, "libdislin_d.so"), Cvoid, (Ptr{UInt8},), s)
end

function projct(s::String)
  ccall((:projct, "libdislin_d.so"), Cvoid, (Ptr{UInt8},), s)
end

function psfont(s::String)
  ccall((:psfont, "libdislin_d.so"), Cvoid, (Ptr{UInt8},), s)
end

function psmeta(s1::String, s2::String)
  ccall((:psmeta, "libdislin_d.so"), Cvoid, (Ptr{UInt8}, Ptr{UInt8}), s1, s2)
end

function psmode(s::String)
  ccall((:psmode, "libdislin_d.so"), Cvoid, (Ptr{UInt8},), s)
end

function pt2pos(x1::Float64, x2::Float64)
  xp1 = Cdouble[0]
  xp2 = Cdouble[0]
  ccall((:pt2pos, "libdislin_d.so"), Cvoid, (Float64, Float64, 
          Ptr{Cdouble}, Ptr{Cdouble}), x1, x2, xp1, xp2)
  return xp1[1], xp2[1]
end

function pyra3d(x1::Float64, x2::Float64, x3::Float64, x4::Float64,
           x5::Float64, x6::Float64, i::Int64)
  ccall((:pyra3d, "libdislin_d.so"), Cvoid, (Float64, Float64, Float64,
          Float64, Float64, Float64, Int32), x1, x2, x3, x4, x5, x6, i)
end

function qplbar(xray::Vector{Float64}, n::Int64)
  ccall((:qplbar, "libdislin_d.so"), Cvoid, (Ptr{Float64}, Int32), xray, n)
end

function qplclr(zmat::Array{Float64, 2}, n::Int64, m::Int64)
  z = transpose(zmat)
  ccall((:qplclr, "libdislin_d.so"), Cvoid, (Ptr{Float64}, Int32, Int32), z, n, m)
  z = 0  # free z
end

function qplcon(zmat::Array{Float64, 2}, n::Int64, m::Int64, nlv::Int64)
  z = transpose(zmat)
  ccall((:qplcon, "libdislin_d.so"), Cvoid, (Ptr{Float64}, Int32, Int32, Int32), 
           z, n, m, nlv)
  z = 0  # free z
end

function qplcrv(xray::Vector{Float64}, yray::Vector{Float64}, n::Int64,
                s::String)
  ccall((:qplcrv, "libdislin_d.so"), Cvoid, 
         (Ptr{Float64}, Ptr{Float64}, Int32, Ptr{UInt8}), xray, yray, n, s)
end

function qplot(xray::Vector{Float64}, yray::Vector{Float64}, n::Int64)
  ccall((:qplot, "libdislin_d.so"), Cvoid, 
         (Ptr{Float64}, Ptr{Float64}, Int32), xray, yray, n)
end

function qplpie(xray::Vector{Float64}, n::Int64)
  ccall((:qplpie, "libdislin_d.so"), Cvoid, (Ptr{Float64}, Int32), xray, n)
end

function qplsca(xray::Vector{Float64}, yray::Vector{Float64}, n::Int64)
  ccall((:qplsca, "libdislin_d.so"), Cvoid, 
         (Ptr{Float64}, Ptr{Float64}, Int32), xray, yray, n)
end

#void  qplscl (double a, double e, double org, double stp, const char *copt);

function qplsur(zmat::Array{Float64, 2}, n::Int64, m::Int64)
  z = transpose(zmat)
  ccall((:qplsur, "libdislin_d.so"), Cvoid, (Ptr{Float64}, Int32, Int32), 
          z, n, m)
  z = 0  # free z
end

function quad3d(x1::Float64, x2::Float64, x3::Float64, x4::Float64,
              x5::Float64, x6::Float64)
  ccall((:quad3d, "libdislin_d.so"), Cvoid, (Float64, Float64, Float64,
          Float64, Float64, Float64), x1, x2, x3, x4, x5, x6)
end

function rbfpng(iray::Vector{UInt8}, nmax::Int64) 
  n = ccall((:rbfpng, "libdislin_d.so"), Int32, (Ptr{UInt8}, Int32),
          iray, nmax)
  return convert(Int64, n)
end

function rbmp(s::String)
  ccall((:rbmp, "libdislin_d.so"), Cvoid, (Ptr{UInt8},), s)
end

function readfl(i1::Int64, iray::Vector{UInt8}, i2::Int64) 
  n = ccall((:readfl, "libdislin_d.so"), Int32, (Int32, Ptr{UInt8}, Int32),
          i1, iray, i2)
  return convert(Int64, n)
end

function reawgt()
  ccall((:reawgt, "libdislin_d.so"), Cvoid, ())
end

function recfll(i1::Int64, i2::Int64, i3::Int64, i4::Int64, i5::Int64)
  ccall((:recfll, "libdislin_d.so"), Cvoid, (Int32, Int32, Int32, Int32, Int32), 
           i1, i2, i3, i4, i5)
end

function rectan(i1::Int64, i2::Int64, i3::Int64, i4::Int64)
  ccall((:rectan, "libdislin_d.so"), Cvoid, (Int32, Int32, Int32, Int32), 
           i1, i2, i3, i4)
end

function rel3pt(x1::Float64, x2::Float64, x3::Float64)
  xp1 = Cdouble[0]
  xp2 = Cdouble[0]
  ccall((:rel3pt, "libdislin_d.so"), Cvoid, (Float64, Float64, Float64,
          Ptr{Cdouble}, Ptr{Cdouble}), x1, x2, x3, xp1, xp2)
  return xp1[1], xp2[1]
end

function resatt()
  ccall((:resatt, "libdislin_d.so"), Cvoid, ())
end

function reset(s::String)
  ccall((:reset, "libdislin_d.so"), Cvoid, (Ptr{UInt8},), s)
end

function revscr()
  ccall((:revscr, "libdislin_d.so"), Cvoid, ())
end

function rgbhsv(x1::Float64, x2::Float64, x3::Float64)
  xp1 = Cdouble[0]
  xp2 = Cdouble[0]
  xp3 = Cdouble[0]
  ccall((:rgbhsv, "libdislin_d.so"), Cvoid, (Float64, Float64, Float64,
          Ptr{Cdouble}, Ptr{Cdouble}, Ptr{Cdouble}), x1, x2, x3, xp1, xp2, xp3)
  return xp1[1], xp2[1], xp3[1] 
end

function rgif(s::String)
  ccall((:rgif, "libdislin_d.so"), Cvoid, (Ptr{UInt8},), s)
end

function rgtlab()
  ccall((:rgtlab, "libdislin_d.so"), Cvoid, ())
end

function rimage(s::String)
  ccall((:rimage, "libdislin_d.so"), Cvoid, (Ptr{UInt8},), s)
end

function rlarc(x1::Float64, x2::Float64, x3::Float64, x4::Float64,
              x5::Float64, x6::Float64, x7::Float64)
  ccall((:rlarc, "libdislin_d.so"), Cvoid, (Float64, Float64, Float64,
          Float64, Float64, Float64, Float64), x1, x2, x3, x4, x5, x6, x7)
end

function rlarea(xray::Vector{Float64}, yray::Vector{Float64}, n::Int64)
  ccall((:rlarea, "libdislin_d.so"), Cvoid, 
         (Ptr{Float64}, Ptr{Float64}, Int32), xray, yray, n)
end

function rlcirc(x1::Float64, x2::Float64, x3::Float64)
  ccall((:rlcirc, "libdislin_d.so"), Cvoid, (Float64, Float64, Float64), 
          x1, x2, x3)
end

function rlconn(x1::Float64, x2::Float64)
  ccall((:rlconn, "libdislin_d.so"), Cvoid, (Float64, Float64), x1, x2)
end

function rlell(x1::Float64, x2::Float64, x3::Float64, x4::Float64)
  ccall((:rlell, "libdislin_d.so"), Cvoid, (Float64, Float64, Float64, Float64), 
          x1, x2, x3, x4)
end

function rline(x1::Float64, x2::Float64, x3::Float64, x4::Float64)
  ccall((:rline, "libdislin_d.so"), Cvoid, (Float64, Float64, Float64, Float64), 
          x1, x2, x3, x4)
end

function rlmess(s::String, x1::Float64, x2::Float64)
  ccall((:rlmess, "libdislin_d.so"), Cvoid, (Ptr{UInt8}, Float64, Float64), 
          s, x1, x2)
end

function rlnumb(x1::Float64, i::Int64, x2::Float64, x3::Float64)
  ccall((:rlnumb, "libdislin_d.so"), Cvoid, (Float64, Int32, Float64, Float64), 
          x1, i, x2, x3)
end

function rlpie(x1::Float64, x2::Float64, x3::Float64, x4::Float64,
              x5::Float64)
  ccall((:rlpie, "libdislin_d.so"), Cvoid, (Float64, Float64, Float64,
          Float64, Float64), x1, x2, x3, x4, x5)
end

function rlpoin(x1::Float64, x2::Float64, i1::Int64, i2::Int64,
              i3::Int64)
  ccall((:rlpoin, "libdislin_d.so"), Cvoid, (Float64, Float64, Int32,
          Int32, Int32), x1, x2, i1, i2, i3)
end

function rlrec(x1::Float64, x2::Float64, x3::Float64, x4::Float64)
  ccall((:rlrec, "libdislin_d.so"), Cvoid, (Float64, Float64, Float64, Float64), 
          x1, x2, x3, x4)
end

function rlrnd(x1::Float64, x2::Float64, x3::Float64, x4::Float64, i::Int64)
  ccall((:rlrnd, "libdislin_d.so"), Cvoid, (Float64, Float64, Float64,
          Float64, Int32), x1, x2, x3, x4, i)
end

function rlsec(x1::Float64, x2::Float64, x3::Float64, x4::Float64,
              x5::Float64, x6::Float64, i::Int64)
  ccall((:rlsec, "libdislin_d.so"), Cvoid, (Float64, Float64, Float64,
          Float64, Float64, Float64, Int32), x1, x2, x3, x4, x5, x6, i)
end

function rlstrt(x1::Float64, x2::Float64)
  ccall((:rlstrt, "libdislin_d.so"), Cvoid, (Float64, Float64), x1, x2)
end

function rlsymb(i::Int64, x1::Float64, x2::Float64)
  ccall((:rlsymb, "libdislin_d.so"), Cvoid, (Int32, Float64, Float64), i, x1, x2)
end

function rlvec(x1::Float64, x2::Float64, x3::Float64, x4::Float64, i::Int64)
  ccall((:rlvec, "libdislin_d.so"), Cvoid, (Float64, Float64, Float64,
          Float64, Int32), x1, x2, x3, x4, i)
end

function rlwind(x1::Float64, x2::Float64, x3::Float64, i::Int64, x4::Float64)
  ccall((:rlwind, "libdislin_d.so"), Cvoid, (Float64, Float64, Float64,
          Int32, Float64), x1, x2, x3, i, x4)
end

function rndrec(i1::Int64, i2::Int64, i3::Int64, i4::Int64, i5::Int64)
  ccall((:rndrec, "libdislin_d.so"), Cvoid, (Int32, Int32, Int32, Int32, Int32), 
           i1, i2, i3, i4, i5)
end

function rot3d(x1::Float64, x2::Float64, x3::Float64)
  ccall((:rot3d, "libdislin_d.so"), Cvoid, (Float64, Float64, Float64), 
          x1, x2, x3)
end

function rpixel(i1::Int64, i2::Int64)
  iclr = Cint[0]
  ccall((:rpixel, "libdislin_d.so"), Cvoid, (Int32, Int32, Ptr{Cint}), 
          i1, i2, iclr)
  return convert(Int64, iclr[1])
end

function rpixls(iray::Vector{UInt8}, i1::Int64, i2::Int64, i3::Int64, 
                i4::Int64)
  ccall((:rpixls, "libdislin_d.so"), Cvoid, (Ptr{UInt8}, Int32, Int32, Int32, 
          Int32), iray, i1, i2, i3, i4)
end

function rpng(s::String)
  ccall((:rpng, "libdislin_d.so"), Cvoid, (Ptr{UInt8},), s)
end

function rppm(s::String)
  ccall((:rppm, "libdislin_d.so"), Cvoid, (Ptr{UInt8},), s)
end

function rpxrow(iray::Vector{UInt8}, i1::Int64, i2::Int64, i3::Int64) 
  ccall((:rpxrow, "libdislin_d.so"), Cvoid, (Ptr{UInt8}, Int32, Int32, Int32),
          iray, i1, i2, i3)
end

function rtiff(s::String)
  ccall((:rtiff, "libdislin_d.so"), Cvoid, (Ptr{UInt8},), s)
end

function rvynam()
  ccall((:rvynam, "libdislin_d.so"), Cvoid, ())
end

function scale(s1::String, s2::String)
  ccall((:scale, "libdislin_d.so"), Cvoid, (Ptr{UInt8}, Ptr{UInt8}), s1, s2)
end

function sclfac(x::Float64)
  ccall((:sclfac, "libdislin_d.so"), Cvoid, (Float64,), x)
end

function sclmod(s::String)
  ccall((:sclmod, "libdislin_d.so"), Cvoid, (Ptr{UInt8},), s)
end

function scrmod(s::String)
  ccall((:scrmod, "libdislin_d.so"), Cvoid, (Ptr{UInt8},), s)
end

function sector(i1::Int64, i2::Int64, i3::Int64, i4::Int64, x1::Float64,
                x2::Float64, i5::Int64)
  ccall((:sector, "libdislin_d.so"), Cvoid, (Int32, Int32, Int32, Int32, Float64,
          Float64, Int32), i1, i2, i3, i4, x1, x2, i5)
end

function selwin(i::Int64)
  ccall((:selwin, "libdislin_d.so"), Cvoid, (Int32,), i)
end

function sendbf()
  ccall((:sendbf, "libdislin_d.so"), Cvoid, ())
end

function sendmb()
  ccall((:sendmb, "libdislin_d.so"), Cvoid, ())
end

function sendok()
  ccall((:sendok, "libdislin_d.so"), Cvoid, ())
end

function serif()
  ccall((:serif, "libdislin_d.so"), Cvoid, ())
end

function setbas(x::Float64)
  ccall((:setbas, "libdislin_d.so"), Cvoid, (Float64,), x)
end

function setcbk(func::Function, s::String)
  func_c = @cfunction $func Cvoid (Ptr{Cdouble}, Ptr{Cdouble}) 
  ccall((:setcbk, "libdislin_d.so"), Cvoid, (Ptr{Cvoid}, Ptr{UInt8}), 
          func_c, s)
end

function setclr(i::Int64)
  ccall((:setclr, "libdislin_d.so"), Cvoid, (Int32,), i)
end

function setscr(s::String)
  ccall((:setscr, "libdislin_d.so"), Cvoid, (Ptr{UInt8},), s)
end

function setexp(x::Float64)
  ccall((:setexp, "libdislin_d.so"), Cvoid, (Float64,), x)
end

function setfce(s::String)
  ccall((:setfce, "libdislin_d.so"), Cvoid, (Ptr{UInt8},), s)
end

function setfil(s::String)
  ccall((:setfil, "libdislin_d.so"), Cvoid, (Ptr{UInt8},), s)
end

function setgrf(s1::String, s2::String, s3::String, 
                s4::String)
  ccall((:setgrf, "libdislin_d.so"), Cvoid, (Ptr{UInt8}, Ptr{UInt8}, Ptr{UInt8},
          Ptr{UInt8}), s1, s2, s3, s4)
end

function setind(i::Int64, x1::Float64, x2::Float64, x3::Float64)
  ccall((:setind, "libdislin_d.so"), Cvoid, (Int32, Float64, Float64, Float64), 
           i, x1, x2, x3)
end

function setmix(s1::String, s2::String)
  ccall((:setmix, "libdislin_d.so"), Cvoid, (Ptr{UInt8}, Ptr{UInt8}), s1, s2)
end

function setpag(s::String)
  ccall((:setpag, "libdislin_d.so"), Cvoid, (Ptr{UInt8},), s)
end

function setres(i1::Int64, i2::Int64)
  ccall((:setres, "libdislin_d.so"), Cvoid, (Int32, Int32), i1, i2)
end

function setres3d(x1::Float64, x2::Float64, x3::Float64)
  ccall((:setres3d, "libdislin_d.so"), Cvoid, (Float64, Float64, Float64), 
              x1, x2, x3)
end

function setrgb(x1::Float64, x2::Float64, x3::Float64)
  ccall((:setrgb, "libdislin_d.so"), Cvoid, (Float64, Float64, Float64), 
              x1, x2, x3)
end

function setscl(xray::Vector{Float64}, n::Int64, s::String)
  ccall((:setscl, "libdislin_d.so"), Cvoid, 
          (Ptr{Float64}, Int32, Ptr{UInt8}), xray, n, s)
end

function setvlt(s::String)
  ccall((:setvlt, "libdislin_d.so"), Cvoid, (Ptr{UInt8},), s)
end

function setxid(i::Int64, s::String)
  ccall((:setxid, "libdislin_d.so"), Cvoid, (Int32, Ptr{UInt8}), i, s)
end

function shdafr(i1ray::Vector{Int32}, i2ray::Vector{Int32}, 
                i3ray::Vector{Int32}, n::Int64)
  ccall((:shdafr, "libdislin_d.so"), Cvoid, 
         (Ptr{Int32}, Ptr{Int32}, Ptr{Int32}, Int32), i1ray, i2ray, i3ray, n)
end

function shdasi(i1ray::Vector{Int32}, i2ray::Vector{Int32}, 
                i3ray::Vector{Int32}, n::Int64)
  ccall((:shdasi, "libdislin_d.so"), Cvoid, 
         (Ptr{Int32}, Ptr{Int32}, Ptr{Int32}, Int32), i1ray, i2ray, i3ray, n)
end

function shdaus(i1ray::Vector{Int32}, i2ray::Vector{Int32}, 
                i3ray::Vector{Int32}, n::Int64)
  ccall((:shdaus, "libdislin_d.so"), Cvoid, 
         (Ptr{Int32}, Ptr{Int32}, Ptr{Int32}, Int32), i1ray, i2ray, i3ray, n)
end

function shdcha()
  ccall((:shdcha, "libdislin_d.so"), Cvoid, ())
end

function shdcrv(x1ray::Vector{Float64}, y1ray::Vector{Float64}, n1::Int64,
                x2ray::Vector{Float64}, y2ray::Vector{Float64}, n2::Int64)
  ccall((:shdcrv, "libdislin_d.so"), Cvoid, (Ptr{Float64}, Ptr{Float64}, 
          Int32, Ptr{Float64}, Ptr{Float64}, Int32), 
          x1ray, y1ray, n1, x2ray, y2ray, n2)
end

function shdeur(i1ray::Vector{Int32}, i2ray::Vector{Int32}, 
                i3ray::Vector{Int32}, n::Int64)
  ccall((:shdeur, "libdislin_d.so"), Cvoid, 
         (Ptr{Int32}, Ptr{Int32}, Ptr{Int32}, Int32), i1ray, i2ray, i3ray, n)
end

function shdfac(x::Float64)
  ccall((:shdfac, "libdislin_d.so"), Cvoid, (Float64,), x)
end

function shdmap(s::String)
  ccall((:shdmap, "libdislin_d.so"), Cvoid, (Ptr{UInt8},), s)
end

function shdmod(s1::String, s2::String)
  ccall((:shdmod, "libdislin_d.so"), Cvoid, (Ptr{UInt8}, Ptr{UInt8}), s1, s2)
end

function shdnor(i1ray::Vector{Int32}, i2ray::Vector{Int32}, 
                i3ray::Vector{Int32}, n::Int64)
  ccall((:shdnor, "libdislin_d.so"), Cvoid, 
         (Ptr{Int32}, Ptr{Int32}, Ptr{Int32}, Int32), i1ray, i2ray, i3ray, n)
end

function shdpat(i::Int64)
  ccall((:shdpat, "libdislin_d.so"), Cvoid, (Clong,), i)
end

function shdsou(i1ray::Vector{Int32}, i2ray::Vector{Int32}, 
                i3ray::Vector{Int32}, n::Int64)
  ccall((:shdsou, "libdislin_d.so"), Cvoid, 
         (Ptr{Int32}, Ptr{Int32}, Ptr{Int32}, Int32), i1ray, i2ray, i3ray, n)
end

function shdusa(i1ray::Vector{Int32}, i2ray::Vector{Int32}, 
                i3ray::Vector{Int32}, n::Int64)
  ccall((:shdusa, "libdislin_d.so"), Cvoid, 
         (Ptr{Int32}, Ptr{Int32}, Ptr{Int32}, Int32), i1ray, i2ray, i3ray, n)
end

function shield(s1::String, s2::String)
  ccall((:shield, "libdislin_d.so"), Cvoid, (Ptr{UInt8}, Ptr{UInt8}), s1, s2)
end

function shlcir(i1::Int64, i2::Int64, i3::Int64)
  ccall((:shlcir, "libdislin_d.so"), Cvoid, (Int32, Int32, Int32), i1, i2, i3)
end

function shldel(i::Int64)
  ccall((:shldel, "libdislin_d.so"), Cvoid, (Int32,), i)
end

function shlell(i1::Int64, i2::Int64, i3::Int64, i4::Int64, x::Float64)
  ccall((:shlell, "libdislin_d.so"), Cvoid, (Int32, Int32, Int32, Int32, 
          Float64), i1, i2, i3, i4, x)
end

function shlind()
  n = ccall((:shlind, "libdislin_d.so"), Int32, ())
  return convert(Int64, n)
end

function shlpie(i1::Int64, i2::Int64, i3::Int64, x1::Float64, x2::Float64)
  ccall((:shlpie, "libdislin_d.so"), Cvoid, (Int32, Int32, Int32, Float64, 
          Float64), i1, i2, i3, x1, x2)
end

function shlpol(ixray::Vector{Int32}, iyray::Vector{Int32}, n::Int64)
  ccall((:shlpol, "libdislin_d.so"), Cvoid, 
         (Ptr{Int32}, Ptr{Int32}, Int32), ixray, iyray, n)
end

function shlrct(i1::Int64, i2::Int64, i3::Int64, i4::Int64, x::Float64)
  ccall((:shlrct, "libdislin_d.so"), Cvoid, (Int32, Int32, Int32, Int32, 
          Float64), i1, i2, i3, i4, x)
end

function shlrec(i1::Int64, i2::Int64, i3::Int64, i4::Int64)
  ccall((:shlrec, "libdislin_d.so"), Cvoid, (Int32, Int32, Int32, Int32), 
           i1, i2, i3, i4)
end

function shlres(i::Int64)
  ccall((:shlres, "libdislin_d.so"), Cvoid, (Int32,), i)
end

function shlsur()
  ccall((:shlsur, "libdislin_d.so"), Cvoid, ())
end

function shlvis(i::Int64, s::String)
  ccall((:shlvis, "libdislin_d.so"), Cvoid, (Int32, Ptr{UInt8}), i, s)
end

function simplx()
  ccall((:simplx, "libdislin_d.so"), Cvoid, ())
end

function skipfl(i1::Int64, i2::Int64)
  n = ccall((:skipfl, "libdislin_d.so"), Int32, (Int32, Int32), i1, i2)
  return convert(Int64, n)
end

function smxalf(s1::String, s2::String, s3::String, i::Int64) 
  ccall((:smxalf, "libdislin_d.so"), Cvoid, (Ptr{UInt8}, Ptr{UInt8}, Ptr{UInt8},
          Int32), s1, s2, s3, i)
end

function solid()
  ccall((:solid, "libdislin_d.so"), Cvoid, ())
end

function sortr1(xray::Vector{Float64}, n::Int64, s::String)
  ccall((:sortr1, "libdislin_d.so"), Cvoid, (Ptr{Float64},  
          Int32, Ptr{UInt8}), xray, n, s)
end

function sortr2(xray::Vector{Float64}, yray::Vector{Float64}, n::Int64,
                s::String)
  ccall((:sortr2, "libdislin_d.so"), Cvoid, (Ptr{Float64}, Ptr{Float64}, 
          Int32, Ptr{UInt8}), xray, yray, n, s)
end

function spcbar(i::Int64)
  ccall((:spcbar, "libdislin_d.so"), Cvoid, (Int32,), i)
end

function sphe3d(x1::Float64, x2::Float64, x3::Float64, x4::Float64,
                i1::Int64, i2::Int64)
  ccall((:sphe3d, "libdislin_d.so"), Cvoid, (Float64, Float64, Float64,
          Float64, Int32, Int32), x1, x2, x3, x4, i1, i2)
end

function spline(xray::Vector{Float64}, yray::Vector{Float64}, n::Int64,
                xsray::Vector{Float64}, ysray::Vector{Float64})
  nspl = Cint[0]
  ccall((:spline, "libdislin_d.so"), Cvoid, 
          (Ptr{Float64}, Ptr{Float64}, Int32, Ptr{Float64}, Ptr{Float64},
           Ptr{Cint}), xray, yray, n, xsray, ysray, nspl)
  return convert(Int64, nspl[1])
end

function splmod(i1::Int64, i2::Int64)
  ccall((:splmod, "libdislin_d.so"), Cvoid, (Int32, Int32), i1, i2)
end

function stmmod(s1::String, s2::String)
  ccall((:stmmod, "libdislin_d.so"), Cvoid, (Ptr{UInt8}, Ptr{UInt8}), s1, s2)
end

function stmopt(i::Int64, s::String)
  ccall((:stmopt, "libdislin_d.so"), Cvoid, (Int32, Ptr{UInt8}), i, s)
end

function stmpts(xmat::Array{Float64, 2}, ymat::Array{Float64, 2},
                nx::Int64, ny::Int64, xp::Vector{Float64}, yp::Vector{Float64},
                x0::Float64, y0::Float64, xray::Vector{Float64}, 
                yray::Vector{Float64}, nmax::Int64)
  x = transpose(xmat)
  y = transpose(ymat)
  n = Cint[0]
  ccall((:stmpts, "libdislin_d.so"), Int32, (Ptr{Float64}, Ptr{Float64}, 
          Int32, Int32, Ptr{Float64}, Ptr{Float64}, Float64, Float64,
          Ptr{Float64}, Ptr{Float64}, Int32, Ptr{Cint}), 
          x, y, nx, ny, xp, yp, x0, y0, xray, yray, nmax, n)
  x = 0
  y = 0 
  return convert(Int64, n[1])
end

function stmpts3d(xv::Array{Float64, 3}, yv::Array{Float64, 3},
                zv::Array{Float64, 3}, nx::Int64, ny::Int64, nz::Int64,
                xp::Vector{Float64}, yp::Vector{Float64}, zp::Vector{Float64},
                x0::Float64, y0::Float64, z0::Float64, xray::Vector{Float64}, 
                yray::Vector{Float64}, zray::Vector{Float64}, nmax::Int64)
  x = transpose(xmat)
  y = transpose(ymat)
  z = transpose(ymat)
  n = Cint[0]
  ccall((:stmpts3d, "libdislin_d.so"), Int32, (Ptr{Float64}, Ptr{Float64}, 
          Ptr{Float64}, Int32, Int32, Int32, Ptr{Float64}, Ptr{Float64}, 
          Ptr{Float64}, Float64, Float64, Float64, Ptr{Float64}, Ptr{Float64}, 
          Ptr{Float64}, Int32, Ptr{Cint}), 
          x, y, z, nx, ny, nz, xp, yp, zp, x0, y0, z0, xray, yray, zray, nmax,
          n)
  x = 0
  y = 0 
  z = 0
  return convert(Int64, n[1])
end

function stmtri(xv::Vector{Float64}, yv::Vector{Float64},
                xp::Vector{Float64}, yp::Vector{Float64}, n::Int64,
                i1ray::Vector{Int32}, i2ray::Vector{Int32}, 
                i3ray::Vector{Int32}, ntri::Int64, 
                xs::Vector{Float64}, ys::Vector{Float64}, nray::Int64)
  ccall((:stmtri, "libdislin_d.so"), Cvoid, 
          (Ptr{Float64}, Ptr{Float64}, Ptr{Float64}, Ptr{Float64}, Int32, 
          Ptr{Int32}, Ptr{Int32}, Ptr{Int32}, Int32, Ptr{Float64},
          Ptr{Float64}, Int32), xv, yv, xp, yp, n, i1ray, i2ray, i3ray,
          ntri, xs, ys, nray)
end

function stmval(x::Float64, s::String)
  ccall((:stmval, "libdislin_d.so"), Cvoid, (Float64, Ptr{UInt8}), x, s)
end

function stream(xmat::Array{Float64, 2}, ymat::Array{Float64, 2},
                nx::Int64, ny::Int64, xp::Vector{Float64}, yp::Vector{Float64},
                xsray::Vector{Float64}, ysray::Vector{Float64}, n::Int64)
  x = transpose(xmat)
  y = transpose(ymat)
  ccall((:stream, "libdislin_d.so"), Cvoid, (Ptr{Float64}, Ptr{Float64}, 
          Int32, Int32, Ptr{Float64}, Ptr{Float64}, 
          Ptr{Float64}, Ptr{Float64}, Int32), 
          x, y, nx, ny, xp, yp, xsray, ysray, n)
  x = 0
  y = 0 
end

function stream3d(xv::Array{Float64, 3}, yv::Array{Float64, 3},
                zv::Array{Float64, 3}, nx::Int64, ny::Int64, nz::Int64,
                xp::Vector{Float64}, yp::Vector{Float64}, zp::Vector{Float64},
                xsray::Vector{Float64}, ysray::Vector{Float64}, 
                zsray::Vector{Float64}, n::Int64)
  x = transpose(xmat)
  y = transpose(ymat)
  z = transpose(ymat)
  ccall((:stream3d, "libdislin_d.so"), Cvoid, (Ptr{Float64}, Ptr{Float64}, 
          Ptr{Float64}, Int32, Int32, Int32, Ptr{Float64}, Ptr{Float64}, 
          Ptr{Float64}, Ptr{Float64}, Ptr{Float64}, Ptr{Float64}, Int32), 
          x, y, z, nx, ny, nz, xp, yp, zp, xsray, ysray, zsray, n)
  x = 0
  y = 0 
  z = 0
end

function strt3d(x1::Float64, x2::Float64, x3::Float64)
  ccall((:strt3d, "libdislin_d.so"), Cvoid, (Float64, Float64, Float64), 
          x1, x2, x3)
end

function strtpt(x1::Float64, x2::Float64)
  ccall((:strtpt, "libdislin_d.so"), Cvoid, (Float64, Float64), x1, x2)
end

function surclr(i1::Int64, i2::Int64)
  ccall((:surclr, "libdislin_d.so"), Cvoid, (Int32, Int32), i1, i2)
end

function surfce(xray::Vector{Float64}, n::Int64, yray::Vector{Float64},
                m::Int64, zmat::Array{Float64, 2})
  z = transpose(zmat)
  ccall((:surfce, "libdislin_d.so"), Cvoid, (Ptr{Float64}, Int32, Ptr{Float64}, 
          Int32, Ptr{Float64}), xray, n, yray, m, z)
  z = 0  # free z
end

function surfcp(zfun::Function, x1::Float64, x2::Float64, x3::Float64,
                x4::Float64, x5::Float64, x6::Float64)
  zfun_c = @cfunction $zfun Cdouble (Cdouble, Cdouble, Cint) 
  ccall((:surfcp, "libdislin_d.so"), Cvoid, 
          (Ptr{Cvoid}, Float64, Float64, Float64, Float64, Float64, Float64), 
          zfun_c, x1, x2, x3, x4, x5, x6)
end

function surfun(zfun::Function, i1::Int64, x1::Float64, i2::Int64, 
                x2::Float64)
  zfun_c = @cfunction $zfun Cdouble (Cdouble, Cdouble) 
  ccall((:surfun, "libdislin_d.so"), Cvoid, 
          (Ptr{Cvoid}, Int32, Float64, Int32, Float64), 
          zfun_c, i1, x1, i2, x2)
end

function suriso(xray::Vector{Float64}, nx::Int64, yray::Vector{Float64},
                ny::Int64, zray::Vector{Float64}, nz::Int64, 
                wmat::Array{Float64, 3}, wlev::Float64)
  w = transpose(wmat)
  ccall((:suriso, "libdislin_d.so"), Cvoid, (Ptr{Float64}, Int32, Ptr{Float64}, 
          Int32, Ptr{Float64}, Int32, Ptr{Float64}, Float64), xray, nx, yray, 
          ny, zray, nz, w, wlev)
  w = 0
end

function surmat(zmat::Array{Float64, 2}, n::Int64, m::Int64, ixpts::Int64, 
                iypts::Int64)
  z = transpose(zmat)
  ccall((:surmat, "libdislin_d.so"), Cvoid, (Ptr{Float64}, Int32, Int32, Int32, 
           Int32), z, n, m, ixpts, iypts)
  z = 0  # free z
end

function surmsh(s::String)
  ccall((:surmsh, "libdislin_d.so"), Cvoid, (Ptr{UInt8},), s)
end

function suropt(s::String)
  ccall((:suropt, "libdislin_d.so"), Cvoid, (Ptr{UInt8},), s)
end

function surshc(xray::Vector{Float64}, n::Int64, yray::Vector{Float64},
                m::Int64, zmat::Array{Float64, 2}, wmat::Array{Float64, 2})
  z = transpose(zmat)
  w = transpose(wmat)
  ccall((:surshc, "libdislin_d.so"), Cvoid, (Ptr{Float64}, Int32, Ptr{Float64}, 
          Int32, Ptr{Float64}, Ptr{Float64}), xray, n, yray, m, z, w)
  z = 0 
  w = 0
end

function surshd(xray::Vector{Float64}, n::Int64, yray::Vector{Float64},
                m::Int64, zmat::Array{Float64, 2})
  z = transpose(zmat)
  ccall((:surshd, "libdislin_d.so"), Cvoid, (Ptr{Float64}, Int32, Ptr{Float64}, 
          Int32, Ptr{Float64}), xray, n, yray, m, z)
  z = 0  # free z
end

function sursze(x1::Float64, x2::Float64, x3::Float64, x4::Float64)
  ccall((:sursze, "libdislin_d.so"), Cvoid, (Float64, Float64, Float64, Float64),
          x1, x2, x3, x4)
end

function surtri(xray::Vector{Float64}, yray::Vector{Float64}, 
                zray::Vector{Float64}, n::Int64, i1ray::Vector{Int32},
                i2ray::Vector{Int32}, i3ray::Vector{Int32}, ntri::Int64)
  ccall((:surtri, "libdislin_d.so"), Cvoid, (Ptr{Float64}, Ptr{Float64}, 
          Ptr{Float64}, Int32, Ptr{Int32}, Ptr{Int32}, Ptr{Int32}, Int32), 
          xray, yray, zray, n, i1ray, i2ray, i3ray, ntri)
end

function survis(s::String)
  ccall((:survis, "libdislin_d.so"), Cvoid, (Ptr{UInt8},), s)
end

function swapi2(iray::Vector{Int16}, n::Int64)
  ccall((:swapi2, "libdislin_d.so"), Cvoid, 
         (Ptr{Int16}, Int32), iray, n)
end

function swapi4(iray::Vector{Int32}, n::Int64)
  ccall((:swapi4, "libdislin_d.so"), Cvoid, 
         (Ptr{Int32}, Int32), iray, n)
end

function swgatt(i::Int64, s1::String, s2::String)
  ccall((:swgatt, "libdislin_d.so"), Cvoid, (Int32, Ptr{UInt8}, Ptr{UInt8}), 
           i, s1, s2)
end

function swgbgd(i::Int64, x1::Float64, x2::Float64, x3::Float64)
  ccall((:swgbgd, "libdislin_d.so"), Cvoid, (Int32, Float64, Float64, Float64), 
           i, x1, x2, x3)
end

function swgbox(i1::Int64, i2::Int64)
  ccall((:swgbox, "libdislin_d.so"), Cvoid, (Int32, Int32), i1, i2)
end

function swgbut(i1::Int64, i2::Int64)
  ccall((:swgbut, "libdislin_d.so"), Cvoid, (Int32, Int32), i1, i2)
end

function swgcb2(i::Int64, func::Function)
  func_c = @cfunction $func Cvoid (Cint, Cint, Cint) 
  ccall((:swgcb2, "libdislin_d.so"), Cvoid, (Int32, Ptr{Cvoid}), i, func_c)
end

function swgcb3(i::Int64, func::Function)
  func_c = @cfunction $func Cvoid (Cint, Cint) 
  ccall((:swgcb3, "libdislin_d.so"), Cvoid, (Int32, Ptr{Cvoid}), i, func_c)
end

function swgcbk(i::Int64, func::Function)
  func_c = @cfunction $func Cvoid (Cint, ) 
  ccall((:swgcbk, "libdislin_d.so"), Cvoid, (Int32, Ptr{Cvoid}), i, func_c)
end

function swgclr(x1::Float64, x2::Float64, x3::Float64, s::String)
  ccall((:swgclr, "libdislin_d.so"), Cvoid, (Float64, Float64, Float64, 
          Ptr{UInt8}), x1, x2, x3, s)
end

function swgdrw(x::Float64)
  ccall((:swgdrw, "libdislin_d.so"), Cvoid, (Float64,), x)
end

function swgfgd(i::Int64, x1::Float64, x2::Float64, x3::Float64)
  ccall((:swgfgd, "libdislin_d.so"), Cvoid, (Int32, Float64, Float64, Float64), 
           i, x1, x2, x3)
end

function swgfil(i::Int64, s::String)
  ccall((:swgfil, "libdislin_d.so"), Cvoid, (Int32, Ptr{UInt8}), i, s)
end

function swgflt(i1::Int64, x::Float64, i2::Int64)
  ccall((:swgflt, "libdislin_d.so"), Cvoid, (Int32, Float64, Int32), i1, x, i2)
end

function swgfnt(s::String, i::Int64)
  ccall((:swgfnt, "libdislin_d.so"), Cvoid, (Ptr{UInt8}, Int32), s, i)
end

function swgfoc(i::Int64)
  ccall((:swgfoc, "libdislin_d.so"), Cvoid, (Int32,), i)
end

function swghlp(s::String)
  ccall((:swghlp, "libdislin_d.so"), Cvoid, (Ptr{UInt8},), s)
end

function swgint(i1::Int64, i2::Int64)
  ccall((:swgint, "libdislin_d.so"), Cvoid, (Int32, Int32), i1, i2)
end

function swgiop(i::Int64, s::String)
  ccall((:swgiop, "libdislin_d.so"), Cvoid, (Int32, Ptr{UInt8}), i, s)
end

function swgjus(s1::String, s2::String)
  ccall((:swgjus, "libdislin_d.so"), Cvoid, (Ptr{UInt8}, Ptr{UInt8}), s1, s2)
end

function swglis(i1::Int64, i2::Int64)
  ccall((:swglis, "libdislin_d.so"), Cvoid, (Int32, Int32), i1, i2)
end

function swgmix(s1::String, s2::String)
  ccall((:swgmix, "libdislin_d.so"), Cvoid, (Ptr{UInt8}, Ptr{UInt8}), s1, s2)
end

function swgmrg(i::Int64, s::String)
  ccall((:swgmrg, "libdislin_d.so"), Cvoid, (Int32, Ptr{UInt8}), i, s)
end

function swgoff(i1::Int64, i2::Int64)
  ccall((:swgoff, "libdislin_d.so"), Cvoid, (Int32, Int32), i1, i2)
end

function swgopt(s1::String, s2::String)
  ccall((:swgopt, "libdislin_d.so"), Cvoid, (Ptr{UInt8}, Ptr{UInt8}), s1, s2)
end

function swgpop(s::String)
  ccall((:swgpop, "libdislin_d.so"), Cvoid, (Ptr{UInt8},), s)
end

function swgpos(i1::Int64, i2::Int64)
  ccall((:swgpos, "libdislin_d.so"), Cvoid, (Int32, Int32), i1, i2)
end

function swgray(xray::Vector{Float64}, n::Int64, s::String)
  ccall((:swgray, "libdislin_d.so"), Cvoid, 
          (Ptr{Float64}, Int32, Ptr{UInt8}), xray, n, s)
end

function swgscl(i::Int64, x::Float64)
  ccall((:swgscl, "libdislin_d.so"), Cvoid, (Int32, Float64), i, x)
end

function swgsiz(i1::Int64, i2::Int64)
  ccall((:swgsiz, "libdislin_d.so"), Cvoid, (Int32, Int32), i1, i2)
end

function swgspc(x1::Float64, x2::Float64)
  ccall((:swgspc, "libdislin_d.so"), Cvoid, (Float64, Float64), x1, x2)
end

function swgstp(x::Float64)
  ccall((:swgstp, "libdislin_d.so"), Cvoid, (Float64,), x)
end

function swgtbf(i1::Int64, x::Float64, i2::Int64, i3::Int64, s::String)
  ccall((:swgtbf, "libdislin_d.so"), Cvoid, (Int32, Float64, Int32, Int32,
          Ptr{UInt8}), i1, x, i2, i3, s)
end

function swgtbi(i1::Int64, i2::Int64, i3::Int64, i4::Int64, s::String)
  ccall((:swgtbi, "libdislin_d.so"), Cvoid, (Int32, Int32, Int32, Int32,
          Ptr{UInt8}), i1, i2, i3, i4, s)
end

function swgtbl(i1::Int64, xray::Vector{Float64}, n::Int64, i2::Int64,
                i3::Int64, s::String)
  ccall((:swgtbl, "libdislin_d.so"), Cvoid, (Int32, Ptr{Float64}, Int32, 
          Int32, Int32, Ptr{UInt8}), i1, xray, n, i2, i3, s)
end

function swgtbs(i1::Int64, s1::String, i2::Int64, i3::Int64, 
                s2::String)
  ccall((:swgtbs, "libdislin_d.so"), Cvoid, (Int32, Ptr{UInt8}, Int32, Int32,
          Ptr{UInt8}), i1, s1, i2, i3, s2)
end

function swgtit(s::String)
  ccall((:swgtit, "libdislin_d.so"), Cvoid, (Ptr{UInt8},), s)
end

function swgtxt(i::Int64, s::String)
  ccall((:swgtxt, "libdislin_d.so"), Cvoid, (Int32, Ptr{UInt8}), i, s)
end

function swgtyp(s1::String, s2::String)
  ccall((:swgtyp, "libdislin_d.so"), Cvoid, (Ptr{UInt8}, Ptr{UInt8}), s1, s2)
end

function swgval(i::Int64, x::Float64)
  ccall((:swgval, "libdislin_d.so"), Cvoid, (Int32, Float64), i, x)
end

function swgwin(i1::Int64, i2::Int64, i3::Int64, i4::Int64)
  ccall((:swgwin, "libdislin_d.so"), Cvoid, (Int32, Int32, Int32, Int32), 
           i1, i2, i3, i4)
end

function swgwth(i::Int64)
  ccall((:swgwth, "libdislin_d.so"), Cvoid, (Int32,), i)
end

function sym3d(i::Int64, x1::Float64, x2::Float64, x3::Float64)
  ccall((:sym3d, "libdislin_d.so"), Cvoid, (Int32, Float64, Float64, Float64),
          i, x1, x2, x3)
end

function symbol(i1::Int64, i2::Int64, i3::Int64)
  ccall((:symbol, "libdislin_d.so"), Cvoid, (Int32, Int32, Int32), i1, i2, i3)
end

function symfil(s1::String, s2::String)
  ccall((:symfil, "libdislin_d.so"), Cvoid, (Ptr{UInt8}, Ptr{UInt8}), s1, s2)
end

function symrot(x::Float64)
  ccall((:symrot, "libdislin_d.so"), Cvoid, (Float64,), x)
end

function tellfl(i::Int64)
  n = ccall((:tellfl, "libdislin_d.so"), Int32, (Int32, ), i)
  return convert(Int64, n)
end

function texmod(s::String)
  ccall((:texmod, "libdislin_d.so"), Cvoid, (Ptr{UInt8},), s)
end

function texopt(s1::String, s2::String)
  ccall((:texopt, "libdislin_d.so"), Cvoid, (Ptr{UInt8}, Ptr{UInt8}), s1, s2)
end

function texval(x::Float64, s::String)
  ccall((:texval, "libdislin_d.so"), Cvoid, (Float64, Ptr{UInt8}), x, s)
end

function thkc3d(x::Float64)
  ccall((:thkc3d, "libdislin_d.so"), Cvoid, (Float64,), x)
end

function thkcrv(i::Int64)
  ccall((:thkcrv, "libdislin_d.so"), Cvoid, (Int32,), i)
end

function thrfin()
  ccall((:thrfin, "libdislin_d.so"), Cvoid, ())
end

function thrini(i::Int64)
  ccall((:thrini, "libdislin_d.so"), Cvoid, (Int32,), i)
end

function ticks(i::Int64, s::String)
  ccall((:ticks, "libdislin_d.so"), Cvoid, (Int32, Ptr{UInt8}), i, s)
end

function ticlen(i1::Int64, i2::Int64)
  ccall((:ticlen, "libdislin_d.so"), Cvoid, (Int32, Int32), i1, i2)
end

function ticmod(s1::String, s2::String)
  ccall((:ticmod, "libdislin_d.so"), Cvoid, (Ptr{UInt8}, Ptr{UInt8}), s1, s2)
end

function ticpos(s1::String, s2::String)
  ccall((:ticpos, "libdislin_d.so"), Cvoid, (Ptr{UInt8}, Ptr{UInt8}), s1, s2)
end

function tifmod(i::Int64, s1::String, s2::String)
  ccall((:tifmod, "libdislin_d.so"), Cvoid, (Int32, Ptr{UInt8}, Ptr{UInt8}), 
          i, s1, s2)
end

function tiforg(i1::Int64, i2::Int64)
  ccall((:tiforg, "libdislin_d.so"), Cvoid, (Int32, Int32), i1, i2)
end

function tifwin(i1::Int64, i2::Int64, i3::Int64, i4::Int64)
  ccall((:tifwin, "libdislin_d.so"), Cvoid, (Int32, Int32, Int32, Int32), 
           i1, i2, i3, i4)
end

function timopt()
  ccall((:timopt, "libdislin_d.so"), Cvoid, ())
end

function titjus(s::String)
  ccall((:titjus, "libdislin_d.so"), Cvoid, (Ptr{UInt8},), s)
end

function title()
  ccall((:title, "libdislin_d.so"), Cvoid, ())
end

function titlin(s::String, i::Int64)
  ccall((:titlin, "libdislin_d.so"), Cvoid, (Ptr{UInt8}, Int32,), s, i)
end

function titpos(s::String)
  ccall((:titpos, "libdislin_d.so"), Cvoid, (Ptr{UInt8},), s)
end

function torus3d(x1::Float64, x2::Float64, x3::Float64, x4::Float64,
                 x5::Float64, x6::Float64, x7::Float64, x8::Float64, 
                 i1::Int64, i2::Int64)
  ccall((:torus3d, "libdislin_d.so"), Cvoid, (Float64, Float64, Float64,
          Float64, Float64, Float64, Float64, Float64, Int32, Int32), 
          x1, x2, x3, x4, x5, x6, x7, x8, i1, i2)
end

function tprfin()
  ccall((:tprfin, "libdislin_d.so"), Cvoid, ())
end

function tprini()
  ccall((:tprini, "libdislin_d.so"), Cvoid, ())
end

function tprmod(s1::String, s2::String)
  ccall((:tprmod, "libdislin_d.so"), Cvoid, (Ptr{UInt8}, Ptr{UInt8}), s1, s2)
end

function tprval(x::Float64)
  ccall((:tprval, "libdislin_d.so"), Cvoid, (Float64,), x)
end

function tr3axs(x1::Float64, x2::Float64, x3::Float64, x4::Float64)
  ccall((:tr3axs, "libdislin_d.so"), Cvoid, (Float64, Float64, Float64, Float64),
          x1, x2, x3, x4)
end

function tr3res()
  ccall((:tr3res, "libdislin_d.so"), Cvoid, ())
end

function tr3rot(x1::Float64, x2::Float64, x3::Float64)
  ccall((:tr3rot, "libdislin_d.so"), Cvoid, (Float64, Float64, Float64), 
          x1, x2, x3)
end

function tr3scl(x1::Float64, x2::Float64, x3::Float64)
  ccall((:tr3scl, "libdislin_d.so"), Cvoid, (Float64, Float64, Float64), 
          x1, x2, x3)
end

function tr3shf(x1::Float64, x2::Float64, x3::Float64)
  ccall((:tr3shf, "libdislin_d.so"), Cvoid, (Float64, Float64, Float64), 
          x1, x2, x3)
end

function trfco1(xray::Vector{Float64}, n::Int64, s1::String,
                s2::String)
  ccall((:trfco1, "libdislin_d.so"), Cvoid, 
          (Ptr{Float64}, Int32, Ptr{UInt8}, Ptr{UInt8}), xray, n, s1, s2)
end

function trfco2(xray::Vector{Float64}, yray::Vector{Float64}, n::Int64, 
                s1::String, s2::String)
  ccall((:trfco2, "libdislin_d.so"), Cvoid, (Ptr{Float64}, 
          Ptr{Float64}, Int32, Ptr{UInt8}, Ptr{UInt8}), xray, yray, n, s1, s2)
end

function trfco3(xray::Vector{Float64}, yray::Vector{Float64}, 
                zray::Vector{Float64}, n::Int64, 
                s1::String, s2::String)
  ccall((:trfco3, "libdislin_d.so"), Cvoid, (Ptr{Float64}, Ptr{Float64}, 
          Ptr{Float64}, Int32, Ptr{UInt8}, Ptr{UInt8}), 
          xray, yray, zray, n, s1, s2)
end

function trfdat(i::Int64)
  i1 = Cint[0]
  i2 = Cint[0]
  i3 = Cint[0]
  ccall((:trfdat, "libdislin_d.so"), Cvoid, (Int32, Ptr{Cint}, Ptr{Cint}, 
          Ptr{Cint}), i, i1, i2, i3)
  return convert(Int64, i1[1]), convert(Int64, i2[1]), convert(Int64, i3[1])
end
 
function trfmat(zmat::Array{Float64, 2}, n::Int64, m::Int64,
                zmat2::Array{Float64, 2}, n2::Int64, m2::Int64)
  z = transpose(zmat)
  z2 = Array{Float64}(undef, n2, m2)
  ccall((:trfmat, "libdislin_d.so"), Cvoid, (Ptr{Float64}, Int32, Int32,
          Ptr{Float64}, Int32, Int32), z, n, m, z2, n2, m2)
  z = 0
  transpose!(zmat2, z2)
  z2 = 0
end

function trfrel(xray::Vector{Float64}, yray::Vector{Float64}, n::Int64)
  ccall((:trfrel, "libdislin_d.so"), Cvoid, 
          (Ptr{Float64}, Ptr{Float64}, Int32), xray, yray, n)
end

function trfres()
  ccall((:trfres, "libdislin_d.so"), Cvoid, ())
end

function trfrot(x::Float64, i1::Int64, i2::Int64)
  ccall((:trfrot, "libdislin_d.so"), Cvoid, (Float64, Int32, Int32), x, i1, i2)
end

function trfscl(x1::Float64, x2::Float64)
  ccall((:trfscl, "libdislin_d.so"), Cvoid, (Float64, Float64), x1, x2)
end

function trfshf(i1::Int64, i2::Int64)
  ccall((:trfshf, "libdislin_d.so"), Cvoid, (Int32, Int32), i1, i2)
end

function tria3d(xray::Vector{Float64}, yray::Vector{Float64}, 
                zray::Vector{Float64})
  ccall((:tria3d, "libdislin_d.so"), Cvoid, 
          (Ptr{Float64}, Ptr{Float64}, Ptr{Float64}), xray, yray, zray)
end

function triang(xray::Vector{Float64}, yray::Vector{Float64}, 
                n::Int64, i1ray::Vector{Int32}, i2ray::Vector{Int32}, 
                i3ray::Vector{Int32}, nmax::Int64)
  ntri = ccall((:triang, "libdislin_d.so"), Int32, (Ptr{Float64}, Ptr{Float64}, 
          Int32, Ptr{Int32}, Ptr{Int32}, Ptr{Int32}, Int32),
          xray, yray, n, i1ray, i2ray, i3ray, nmax)
  return convert(Int64, ntri)
end

function triflc(xray::Vector{Float64}, yray::Vector{Float64}, 
                iray::Vector{Int32}, n::Int64)
  ccall((:triflc, "libdislin_d.so"), Cvoid, (Ptr{Float64}, Ptr{Float64}, 
          Ptr{Int32}, Int32), xray, yray, iray, n)
end

function trifll(xray::Vector{Float64}, yray::Vector{Float64})
  ccall((:trifll, "libdislin_d.so"), Cvoid, 
          (Ptr{Float64}, Ptr{Float64}), xray, yray)
end

function triplx()
  ccall((:triplx, "libdislin_d.so"), Cvoid, ())
end

function tripts(xray::Vector{Float64}, yray::Vector{Float64}, 
                zray::Vector{Float64}, n::Int64, i1ray::Vector{Int32}, 
                i2ray::Vector{Int32}, i3ray::Vector{Int32}, ntri::Int64, 
                zlev::Float64, xpts::Vector{Float64}, ypts::Vector{Float64}, 
                maxpts::Int64, nptray::Vector{Int32}, maxray::Int64)
  nlines = Cint[0]
  ccall((:tripts, "libdislin_d.so"), Cvoid, (Ptr{Float64}, Ptr{Float64}, 
          Ptr{Float64}, Int32, Ptr{Int32}, Ptr{Int32}, Ptr{Int32}, Int32, 
          Float64, Ptr{Float64}, Ptr{Float64}, Int32, Ptr{Int32}, Int32,
          Ptr{Cint}), xray, yray, zray, n, i1ray, i2ray, i3ray, ntri, zlev,
          xpts, ypts, maxpts, nptray, maxray, nlines)
  return convert(Int64, nlines[1])
end

function trmlen(s::String)
  n = ccall((:trmlen, "libdislin_d.so"), Int32, (Ptr{UInt8},), s)
  return convert(Int64, n)
end

function ttfont(s::String)
  ccall((:ttfont, "libdislin_d.so"), Cvoid, (Ptr{UInt8},), s)
end

function tube3d(x1::Float64, x2::Float64, x3::Float64, x4::Float64,
           x5::Float64, x6::Float64, x7::Float64, i1::Int64, i2::Int64)
  ccall((:tube3d, "libdislin_d.so"), Cvoid, (Float64, Float64, Float64,
          Float64, Float64, Float64, Float64, Int32, Int32), 
          x1, x2, x3, x4, x5, x6, x7, i1, i2)
end

function txtbgd(i::Int64)
  ccall((:txtbgd, "libdislin_d.so"), Cvoid, (Int32,), i)
end

function txtjus(s::String)
  ccall((:txtjus, "libdislin_d.so"), Cvoid, (Ptr{UInt8},), s)
end

function txture(itmat::Array{Int32, 2}, nx::Int64, ny::Int64)
  imat = Array{Int32}(undef, nx, ny)
  ccall((:txture, "libdislin_d.so"), Cvoid, (Ptr{Int32}, Int32, Int32),
          imat, nx, ny)
  transpose!(itmat, imat)
  imat = 0
end

function unit(i::Int64)
  ccall((:unit, "libdislin_d.so"), Cvoid, (Int32,), i)
end

function units(s::String)
  ccall((:units, "libdislin_d.so"), Cvoid, (Ptr{UInt8},), s)
end

function upstr(s::String)
  return uppercase(s)
end

function utfint(s::String, iray::Vector{Int32}, nmax::Int64)
  n = ccall((:utfint, "libdislin_d.so"), Int32, (Ptr{UInt8}, Ptr{Int32},
              Int32), s, iray, nmax)
  return convert(Int64, n)
end

function vang3d(x::Float64)
  ccall((:vang3d, "libdislin_d.so"), Cvoid, (Float64,), x)
end

function vclp3d(x1::Float64, x2::Float64)
  ccall((:vclp3d, "libdislin_d.so"), Cvoid, (Float64, Float64), x1, x2)
end

function vecclr(i::Int64)
  ccall((:vecclr, "libdislin_d.so"), Cvoid, (Int32,), i)
end

function vecf3d(xv::Vector{Float64}, yv::Vector{Float64}, 
                zv::Vector{Float64}, xp::Vector{Float64}, 
                yp::Vector{Float64}, zp::Vector{Float64}, 
                n::Int64, ivec::Int64)
  ccall((:vecf3d, "libdislin_d.so"), Cvoid, (Ptr{Float64}, Ptr{Float64}, 
          Ptr{Float64}, Ptr{Float64}, Ptr{Float64}, Ptr{Float64},
          Int32, Int32), xv, yv, zv, xp, yp, zp, n, ivec)
end

function vecfld(xv::Vector{Float64}, yv::Vector{Float64}, 
                xp::Vector{Float64}, yp::Vector{Float64}, 
                n::Int64, ivec::Int64)
  ccall((:vecfld, "libdislin_d.so"), Cvoid, (Ptr{Float64}, Ptr{Float64}, 
          Ptr{Float64}, Ptr{Float64}, Int32, Int32), xv, yv, xp, yp, n, ivec)
end

function vecmat(xmat::Array{Float64, 2}, ymat::Array{Float64, 2},
                nx::Int64, ny::Int64, xp::Vector{Float64}, yp::Vector{Float64},
                ivec::Int64)
  x = transpose(xmat)
  y = transpose(ymat)
  ccall((:vecmat, "libdislin_d.so"), Cvoid, (Ptr{Float64}, Ptr{Float64}, 
          Int32, Int32, Ptr{Float64}, Ptr{Float64}, Int32), 
          x, y, nx, ny, xp, yp, ivec)
  x = 0
  y = 0 
end

function vecmat3d(xmat::Array{Float64, 2}, ymat::Array{Float64, 2},
                  zmat::Array{Float64, 2}, nx::Int64, ny::Int64, nz::Int64,
                  xp::Vector{Float64}, yp::Vector{Float64},
                  zp::Vector{Float64}, ivec::Int64)
  x = transpose(xmat)
  y = transpose(ymat)
  z = transpose(zmat)
  ccall((:vecmat3d, "libdislin_d.so"), Cvoid, (Ptr{Float64}, Ptr{Float64}, 
          Ptr{Float64}, Int32, Int32, Int32, Ptr{Float64}, Ptr{Float64}, 
          Ptr{Float64}, Int32), x, y, z, nx, ny, nz, xp, yp, zp, ivec)
  x = 0
  y = 0 
  z = 0
end

function vecopt(x::Float64, s::String)
  ccall((:vecopt, "libdislin_d.so"), Cvoid, (Float64, Ptr{UInt8}), x, s)
end

function vector(i1::Int64, i2::Int64, i3::Int64, i4::Int64, i5::Int64)
  ccall((:vector, "libdislin_d.so"), Cvoid, (Int32, Int32, Int32, Int32, Int32), 
          i1, i2, i3, i4, i5)
end

function vectr3(x1::Float64, x2::Float64, x3::Float64, x4::Float64,
              x5::Float64, x6::Float64, i::Int64)
  ccall((:vectr3, "libdislin_d.so"), Cvoid, (Float64, Float64, Float64,
          Float64, Float64, Float64, Int32), x1, x2, x3, x4, x5, x6, i)
end

function vfoc3d(x1::Float64, x2::Float64, x3::Float64, s::String)
  ccall((:vfoc3d, "libdislin_d.so"), Cvoid, (Float64, Float64, Float64, 
          Ptr{UInt8}), x1, x2, x3, s)
end

function view3d(x1::Float64, x2::Float64, x3::Float64, s::String)
  ccall((:view3d, "libdislin_d.so"), Cvoid, (Float64, Float64, Float64, 
          Ptr{UInt8}), x1, x2, x3, s)
end

function vkxbar(i::Int64)
  ccall((:vkxbar, "libdislin_d.so"), Cvoid, (Int32,), i)
end

function vkybar(i::Int64)
  ccall((:vkybar, "libdislin_d.so"), Cvoid, (Int32,), i)
end

function vkytit(i::Int64)
  ccall((:vkytit, "libdislin_d.so"), Cvoid, (Int32,), i)
end

function vltfil(s1::String, s2::String)
  ccall((:vltfil, "libdislin_d.so"), Cvoid, (Ptr{UInt8}, Ptr{UInt8}), s1, s2)
end

function vscl3d(x::Float64)
  ccall((:vscl3d, "libdislin_d.so"), Cvoid, (Float64,), x)
end

function vtx3d(xray::Vector{Float64}, yray::Vector{Float64}, 
                zray::Vector{Float64}, n::Int64, s::String)
  ccall((:vtx3d, "libdislin_d.so"), Cvoid, (Ptr{Float64}, Ptr{Float64}, 
          Ptr{Float64}, Int32, Ptr{UInt8}), xray, yray, zray, n, s)
end

function vtxc3d(xray::Vector{Float64}, yray::Vector{Float64}, 
                zray::Vector{Float64}, icray::Vector{Int32}, n::Int64, 
                s::String)
  ccall((:vtxc3d, "libdislin_d.so"), Cvoid, (Ptr{Float64}, Ptr{Float64}, 
          Ptr{Float64}, Ptr{Int32}, Int32, Ptr{UInt8}), xray, yray, zray, 
          icray, n, s)
end

function vtxn3d(xray::Vector{Float64}, yray::Vector{Float64}, 
                zray::Vector{Float64}, xn::Vector{Float64}, 
                yn::Vector{Float64}, zn::Vector{Float64}, 
                n::Int64, s::String)
  ccall((:vtxn3d, "libdislin_d.so"), Cvoid, (Ptr{Float64}, Ptr{Float64}, 
          Ptr{Float64}, Ptr{Float64}, Ptr{Float64}, Ptr{Float64},
          Int32, Ptr{UInt8}), xray, yray, zray, xn, yn, zn, n, s)
end

function vup3d(x::Float64)
  ccall((:vup3d, "libdislin_d.so"), Cvoid, (Float64,), x)
end

function wgapp(i::Int64, s::String)
  n = ccall((:wgapp, "libdislin_d.so"), Int32, (Int32, Ptr{UInt8}), i, s)
  return convert(Int64, n)
end

function wgappb(i1::Int64, iray::Vector{UInt8}, i2::Int64, i3::Int64) 
  ccall((:wgappb, "libdislin_d.so"), Cvoid, (Int32, Ptr{UInt8}, Int32, Int32),
          i1, iray, i2, i3)
end

function wgbas(i::Int64, s::String)
  n = ccall((:wgbas, "libdislin_d.so"), Int32, (Int32, Ptr{UInt8}), i, s)
  return convert(Int64, n)
end

function wgbox(i1::Int64, s::String, i2::Int64)
  n = ccall((:wgbox, "libdislin_d.so"), Int32, (Int32, Ptr{UInt8}, Int32), 
               i1, s, i2)
  return convert(Int64, n)
end

function wgbut(i1::Int64, s::String, i2::Int64)
  n = ccall((:wgbut, "libdislin_d.so"), Int32, (Int32, Ptr{UInt8}, Int32), 
               i1, s, i2)
  return convert(Int64, n)
end

function wgcmd(i::Int64, s1::String, s2::String)
  n = ccall((:wgcmd, "libdislin_d.so"), Int32, (Int32, Ptr{UInt8}, Ptr{UInt8}), 
           i, s1, s2)
  return convert(Int64, n)
end

function wgdlis(i1::Int64, s::String, i2::Int64)
  n = ccall((:wgdlis, "libdislin_d.so"), Int32, (Int32, Ptr{UInt8}, Int32), 
               i1, s, i2)
  return convert(Int64, n)
end

function wgdraw(i::Int64)
  n = ccall((:wgdraw, "libdislin_d.so"), Int32, (Int32,), i)
  return convert(Int64, n)
end

function wgfil(i::Int64, s1::String, s2::String, s3::String)
  n = ccall((:wgfil, "libdislin_d.so"), Int32, (Int32, Ptr{UInt8}, Ptr{UInt8},
              Ptr{UInt8}), i, s1, s2, s3)
  return convert(Int64, n)
end

function wgfin()
  ccall((:wgfin, "libdislin_d.so"), Cvoid, ())
end

function wgicon(i1::Int64, s1::String, i2::Int64, i3::Int64, 
                 s2::String)
  n = ccall((:wgicon, "libdislin_d.so"), Int32, (Int32, Ptr{UInt8}, Int32, 
              Int32, Ptr{UInt8}), i1, s1, i2, i3, s2)
  return convert(Int64, n)
end

function wgimg(i1::Int64, s::String, iray::Vector{UInt8}, i2::Int64, 
                i3::Int64) 
  ccall((:wgimg, "libdislin_d.so"), Cvoid, (Int32, Ptr{UInt8}, Ptr{UInt8}, 
          Int32, Int32), i1, s, iray, i2, i3)
end

function wgini(s::String)
  n = ccall((:wgini, "libdislin_d.so"), Int32, (Ptr{UInt8},), s)
  return convert(Int64, n)
end

function wglab(i::Int64, s::String)
  n = ccall((:wglab, "libdislin_d.so"), Int32, (Int32, Ptr{UInt8}), i, s)
  return convert(Int64, n)
end

function wglis(i1::Int64, s::String, i2::Int64)
  n = ccall((:wglis, "libdislin_d.so"), Int32, (Int32, Ptr{UInt8}, Int32), 
               i1, s, i2)
  return convert(Int64, n)
end

function wgltxt(i1::Int64, s1::String, s2::String, i2::Int64)
  n = ccall((:wgltxt, "libdislin_d.so"), Int32, (Int32, Ptr{UInt8}, Ptr{UInt8}, 
              Int32), i1, s1, s2, i2)
  return convert(Int64, n)
end

function wgok(i::Int64)
  n = ccall((:wgok, "libdislin_d.so"), Int32, (Int32,), i)
  return convert(Int64, n)
end

function wgpbar(i::Int64, x1::Float64, x2::Float64, x3::Float64)
  n = ccall((:wgpbar, "libdislin_d.so"), Int32, (Int32, Float64, Float64, 
              Float64), i, x1, x2, x3)
  return convert(Int64, n)
end

function wgpbut(i::Int64, s::String)
  n = ccall((:wgpbut, "libdislin_d.so"), Int32, (Int32, Ptr{UInt8}), i, s)
  return convert(Int64, n)
end

function wgpicon(i1::Int64, s1::String, i2::Int64, i3::Int64, 
                 s2::String)
  n = ccall((:wgpicon, "libdislin_d.so"), Int32, (Int32, Ptr{UInt8}, Int32, 
              Int32, Ptr{UInt8}), i1, s1, i2, i3, s2)
  return convert(Int64, n)
end

function wgpimg(i1::Int64, s::String, iray::Vector{UInt8}, i2::Int64, 
                i3::Int64) 
  ccall((:wgpimg, "libdislin_d.so"), Cvoid, (Int32, Ptr{UInt8}, Ptr{UInt8}, 
          Int32, Int32), i1, s, iray, i2, i3)
end

function wgpop(i::Int64, s::String)
  n = ccall((:wgpop, "libdislin_d.so"), Int32, (Int32, Ptr{UInt8}), i, s)
  return convert(Int64, n)
end

function wgpopb(i1::Int64, iray::Vector{UInt8}, i2::Int64, i3::Int64) 
  ccall((:wgpopb, "libdislin_d.so"), Cvoid, (Int32, Ptr{UInt8}, Int32, Int32),
          i1, iray, i2, i3)
end

function wgquit(i::Int64)
  n = ccall((:wgquit, "libdislin_d.so"), Int32, (Int32,), i)
  return convert(Int64, n)
end

function wgscl(i1::Int64, s::String, x1::Float64, x2::Float64,
               x3::Float64, i2::Int64)
  n = ccall((:wgscl, "libdislin_d.so"), Int32, (Int32, Ptr{UInt8}, Float64,
              Float64, Float64, Int32), i1, s, x1, x2, x3, i2)
  return convert(Int64, n)
end

function wgsep(i::Int64)
  n = ccall((:wgsep, "libdislin_d.so"), Int32, (Int32,), i)
  return convert(Int64, n)
end

function wgstxt(i1::Int64, i2::Int64, i3::Int64)
  n = ccall((:wgstxt, "libdislin_d.so"), Int32, (Int32, Int32, Int32), 
               i1, i2, i3)
  return convert(Int64, n)
end

function wgtbl(i1::Int64, i2::Int64, i3::Int64)
  n = ccall((:wgtbl, "libdislin_d.so"), Int32, (Int32, Int32, Int32), 
               i1, i2, i3)
  return convert(Int64, n)
end

function wgtxt(i::Int64, s::String)
  n = ccall((:wgtxt, "libdislin_d.so"), Int32, (Int32, Ptr{UInt8}), i, s)
  return convert(Int64, n)
end

function widbar(i::Int64)
  ccall((:widbar, "libdislin_d.so"), Cvoid, (Int32,), i)
end

function wimage(s::String)
  ccall((:wimage, "libdislin_d.so"), Cvoid, (Ptr{UInt8},), s)
end
  
function winapp(s::String)
  ccall((:winapp, "libdislin_d.so"), Cvoid, (Ptr{UInt8},), s)
end
  
function wincbk(func::Function)
  func_c = @cfunction $func Cvoid (Cint, Cint, Cint, Cint, Cint) 
  ccall((:wincbk, "libdislin_d.so"), Cvoid, (Ptr{Cvoid}, ), func_c)
end

function windbr(x1::Float64, i1::Int64, i2::Int64, i3::Int64, x2::Float64)
  ccall((:windbr, "libdislin_d.so"), Cvoid, (Float64, Int32, Int32, Int32, 
          Float64), x1, i1, i2, i3, x2)
end

function window(i1::Int64, i2::Int64, i3::Int64, i4::Int64)
  ccall((:window, "libdislin_d.so"), Cvoid, (Int32, Int32, Int32, Int32), 
           i1, i2, i3, i4)
end

function winfin(i::Int64)
  ccall((:winfin, "libdislin_d.so"), Cvoid, (Int32,), i)
end

function winfnt(s::String)
  ccall((:winfnt, "libdislin_d.so"), Cvoid, (Ptr{UInt8},), s)
end

function winico(s::String)
  ccall((:winico, "libdislin_d.so"), Cvoid, (Ptr{UInt8},), s)
end

function winid()
  n = ccall((:winid, "libdislin_d.so"), Int32, ())
  return convert(Int64, n)
end

function winjus(s::String)
  ccall((:winjus, "libdislin_d.so"), Cvoid, (Ptr{UInt8},), s)
end

function winkey(s::String)
  ccall((:winkey, "libdislin_d.so"), Cvoid, (Ptr{UInt8},), s)
end

function winmod(s::String)
  ccall((:winmod, "libdislin_d.so"), Cvoid, (Ptr{UInt8},), s)
end

function winopt(i::Int64, s::String)
  ccall((:winopt, "libdislin_d.so"), Cvoid, (Int32, Ptr{UInt8}), i, s)
end

function winsiz(i1::Int64, i2::Int64)
  ccall((:winsiz, "libdislin_d.so"), Cvoid, (Int32, Int32), i1, i2)
end

function wintit(s::String)
  ccall((:wintit, "libdislin_d.so"), Cvoid, (Ptr{UInt8},), s)
end

function wintyp(s::String)
  ccall((:wintyp, "libdislin_d.so"), Cvoid, (Ptr{UInt8},), s)
end

function wmfmod(s1::String, s2::String)
  ccall((:wmfmod, "libdislin_d.so"), Cvoid, (Ptr{UInt8}, Ptr{UInt8}), s1, s2)
end

function world()
  ccall((:world, "libdislin_d.so"), Cvoid, ())
end

function wpixel(i1::Int64, i2::Int64, i3::Int64)
  ccall((:wpixel, "libdislin_d.so"), Cvoid, (Int32, Int32, Int32), i1, i2, i3)
end

function wpixls(iray::Vector{UInt8}, i1::Int64, i2::Int64, i3::Int64, 
                i4::Int64)
  ccall((:wpixls, "libdislin_d.so"), Cvoid, (Ptr{UInt8}, Int32, Int32, Int32, 
          Int32), iray, i1, i2, i3, i4)
end

function wpxrow(iray::Vector{UInt8}, i1::Int64, i2::Int64, i3::Int64) 
  ccall((:wpxrow, "libdislin_d.so"), Cvoid, (Ptr{UInt8}, Int32, Int32, Int32),
          iray, i1, i2, i3)
end

function writfl(i1::Int64, iray::Vector{UInt8}, i2::Int64) 
  n = ccall((:writfl, "libdislin_d.so"), Int32, (Int32, Ptr{UInt8}, Int32),
          i1, iray, i2)
  return convert(Int64, n)
end

function wtiff(s::String)
  ccall((:wtiff, "libdislin_d.so"), Cvoid, (Ptr{UInt8},), s)
end

function x11fnt(s1::String, s2::String)
  ccall((:x11fnt, "libdislin_d.so"), Cvoid, (Ptr{UInt8}, Ptr{UInt8}), s1, s2)
end

function x11mod(s::String)
  ccall((:x11mod, "libdislin_d.so"), Cvoid, (Ptr{UInt8},), s)
end

function x2dpos(x1::Float64, x2::Float64)
  x = ccall((:x2dpos, "libdislin_d.so"), Float64, (Float64, Float64), x1, x2)
  return x
end

function x3dabs(x1::Float64, x2::Float64, x3::Float64)
  x = ccall((:x3dabs, "libdislin_d.so"), Float64, (Float64, Float64, Float64), 
          x1, x2, x3)
  return x
end

function x3dpos(x1::Float64, x2::Float64, x3::Float64)
  x = ccall((:x3dpos, "libdislin_d.so"), Float64, (Float64, Float64, Float64), 
          x1, x2, x3)
  return x
end

function x3drel(x1::Float64, x2::Float64, x3::Float64)
  x = ccall((:x3drel, "libdislin_d.so"), Float64, (Float64, Float64, Float64), 
          x1, x2, x3)
  return x
end

function xaxgit()
  ccall((:xaxgit, "libdislin_d.so"), Cvoid, ())
end

function xaxis(x1::Float64, x2::Float64, x3::Float64, x4::Float64, i1::Int64,
               s::String, i2::Int64, i3::Int64, i4::Int64)
  ccall((:xaxis, "libdislin_d.so"), Cvoid, (Float64, Float64, Float64, Float64,
          Int32, Ptr{UInt8}, Int32, Int32, Int32), 
          x1, x2, x3, x4, i1, s, i2, i3, i4)
end

function xaxlg(x1::Float64, x2::Float64, x3::Float64, x4::Float64, i1::Int64,
               s::String, i2::Int64, i3::Int64, i4::Int64)
  ccall((:xaxlg, "libdislin_d.so"), Cvoid, (Float64, Float64, Float64, Float64,
          Int32, Ptr{UInt8}, Int32, Int32, Int32), 
          x1, x2, x3, x4, i1, s, i2, i3, i4)
end

function xaxmap(x1::Float64, x2::Float64, x3::Float64, x4::Float64, 
               s::String, i1::Int64, i2::Int64)
  ccall((:xaxmap, "libdislin_d.so"), Cvoid, (Float64, Float64, Float64, Float64,
          Ptr{UInt8}, Int32, Int32), x1, x2, x3, x4, s, i1, i2)
end

function xcross()
  ccall((:xcross, "libdislin_d.so"), Cvoid, ())
end

function xdraw(x1::Float64, x2::Float64)
  ccall((:xdraw, "libdislin_d.so"), Cvoid, (Float64, Float64), x1, x2)
end

function xinvrs(i::Int64)
  x = ccall((:xinvrs, "libdislin_d.so"), Float64, (Int32, ), i)
  return x
end

function xmove(x1::Float64, x2::Float64)
  ccall((:xmove, "libdislin_d.so"), Cvoid, (Float64, Float64), x1, x2)
end

function xposn(x1::Float64)
  x = ccall((:xposn, "libdislin_d.so"), Float64, (Float64, ), x1)
  return x
end

function y2dpos(x1::Float64, x2::Float64)
  x = ccall((:y2dpos, "libdislin_d.so"), Float64, (Float64, Float64), x1, x2)
  return x
end

function y3dabs(x1::Float64, x2::Float64, x3::Float64)
  x = ccall((:y3dabs, "libdislin_d.so"), Float64, (Float64, Float64, Float64), 
          x1, x2, x3)
  return x
end

function y3dpos(x1::Float64, x2::Float64, x3::Float64)
  x = ccall((:y3dpos, "libdislin_d.so"), Float64, (Float64, Float64, Float64), 
          x1, x2, x3)
  return x
end

function y3drel(x1::Float64, x2::Float64, x3::Float64)
  x = ccall((:y3drel, "libdislin_d.so"), Float64, (Float64, Float64, Float64), 
          x1, x2, x3)
  return x
end

function yaxgit()
  ccall((:yaxgit, "libdislin_d.so"), Cvoid, ())
end

function yaxis(x1::Float64, x2::Float64, x3::Float64, x4::Float64, i1::Int64,
               s::String, i2::Int64, i3::Int64, i4::Int64)
  ccall((:yaxis, "libdislin_d.so"), Cvoid, (Float64, Float64, Float64, Float64,
          Int32, Ptr{UInt8}, Int32, Int32, Int32), 
          x1, x2, x3, x4, i1, s, i2, i3, i4)
end

function yaxlg(x1::Float64, x2::Float64, x3::Float64, x4::Float64, i1::Int64,
               s::String, i2::Int64, i3::Int64, i4::Int64)
  ccall((:yaxlg, "libdislin_d.so"), Cvoid, (Float64, Float64, Float64, Float64,
          Int32, Ptr{UInt8}, Int32, Int32, Int32), 
          x1, x2, x3, x4, i1, s, i2, i3, i4)
end

function yaxmap(x1::Float64, x2::Float64, x3::Float64, x4::Float64, 
               s::String, i1::Int64, i2::Int64)
  ccall((:yaxmap, "libdislin_d.so"), Cvoid, (Float64, Float64, Float64, Float64,
          Ptr{UInt8}, Int32, Int32), x1, x2, x3, x4, s, i1, i2)
end

function ycross()
  ccall((:ycross, "libdislin_d.so"), Cvoid, ())
end

function yinvrs(i::Int64)
  x = ccall((:yinvrs, "libdislin_d.so"), Float64, (Int32, ), i)
  return x
end

function ypolar(x1::Float64, x2::Float64, x3::Float64, x4::Float64,
               s::String, i1::Int64)
  ccall((:ypolar, "libdislin_d.so"), Cvoid, (Float64, Float64, Float64, Float64,
          Ptr{UInt8}, Int32), 
          x1, x2, x3, x4, s, i1)
end

function yposn(x1::Float64)
  x = ccall((:yposn, "libdislin_d.so"), Float64, (Float64, ), x1)
  return x
end

function z3dpos(x1::Float64, x2::Float64, x3::Float64)
  x = ccall((:z3dpos, "libdislin_d.so"), Float64, (Float64, Float64, Float64), 
          x1, x2, x3)
  return x
end

function zaxis(x1::Float64, x2::Float64, x3::Float64, x4::Float64, i1::Int64,
               s::String, i2::Int64, i3::Int64, i4::Int64, i5::Int64)
  ccall((:zaxis, "libdislin_d.so"), Cvoid, (Float64, Float64, Float64, Float64,
          Int32, Ptr{UInt8}, Int32, Int32, Int32, Int32), 
          x1, x2, x3, x4, i1, s, i2, i3, i4, i5)
end

function zaxlg(x1::Float64, x2::Float64, x3::Float64, x4::Float64, i1::Int64,
               s::String, i2::Int64, i3::Int64, i4::Int64, i5::Int64)
  ccall((:zaxlg, "libdislin_d.so"), Cvoid, (Float64, Float64, Float64, Float64,
          Int32, Ptr{UInt8}, Int32, Int32, Int32, Int32), 
          x1, x2, x3, x4, i1, s, i2, i3, i4, i5)
end

function zbfers()
  ccall((:zbfers, "libdislin_d.so"), Cvoid, ())
end

function zbffin()
  ccall((:zbffin, "libdislin_d.so"), Cvoid, ())
end

function zbfini()
  n = ccall((:zbfini, "libdislin_d.so"), Int32, ())
  return convert(Int64, n)
end

function zbflin(x1::Float64, x2::Float64, x3::Float64, x4::Float64,
              x5::Float64, x6::Float64)
  ccall((:zbflin, "libdislin_d.so"), Cvoid, (Float64, Float64, Float64,
          Float64, Float64, Float64), x1, x2, x3, x4, x5, x6)
end

function zbfmod(s::String)
  ccall((:zbfmod, "libdislin_d.so"), Cvoid, (Ptr{UInt8},), s)
end

function zbfres()
  ccall((:zbfres, "libdislin_d.so"), Cvoid, ())
end

function zbfscl(x::Float64)
  ccall((:zbfscl, "libdislin_d.so"), Cvoid, (Float64,), x)
end

function zbftri(xray::Vector{Float64}, yray::Vector{Float64}, 
                zray::Vector{Float64}, iray::Vector{Int32})
  ccall((:zbftri, "libdislin_d.so"), Cvoid, (Ptr{Float64}, Ptr{Float64}, 
          Ptr{Float64}, Ptr{Int32}), xray, yray, zray, iray)
end

function zscale(x1::Float64, x2::Float64)
  ccall((:zscale, "libdislin_d.so"), Cvoid, (Float64, Float64), x1, x2)
end

end
