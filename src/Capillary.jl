module Capillary
import PhysicalConstants
import Unitful
import FunctionZeros: besselj_zero
import Roots: fzero
import Cubature: hquadrature
import SpecialFunctions: besselj
import StaticArrays: SVector
using Reexport
@reexport using Luna.AbstractModes
import Luna: Maths
import Luna.PhysData: c, ref_index_fun, roomtemp
import Luna.AbstractModes: AbstractMode, dimlimits, β, α, field

export MarcatilliMode, dimlimits, β, α, field

# core and clad are function-like objects which return the
# refractive index as a function of freq
struct MarcatilliMode{Tcore, Tclad, Tloss} <: AbstractMode
    a::Float64
    n::Int
    m::Int
    kind::Symbol
    unm::Float64
    ϕ::Float64
    coren::Tcore
    cladn::Tclad
    loss::Tloss
end

function MarcatilliMode(a, n, m, kind, ϕ, coren, cladn; loss=αMarcatilli)
    if (kind == :TE) || (kind == :TM)
        if (n != 0) || (m != 1)
            error("n=0, m=1 for TE or TM modes")
        end
        unm = besselj_zero(1, 1)
    elseif kind == :HE
        unm = besselj_zero(n-1, m)
    else
        error("kind must be :TE, :TM or :HE")
    end
    MarcatilliMode(a, n, m, kind, unm, ϕ, coren, cladn, loss)
end

"convenience constructor assunming single gas filling and silica clad"
function MarcatilliMode(a, gas, P; n=1, m=1, kind=:HE, ϕ=0.0, T=roomtemp, loss=αMarcatilli)
    rfg = ref_index_fun(gas, P, T)
    rfs = ref_index_fun(:SiO2)
    coren = ω -> rfg(2π*c./ω)
    cladn = ω -> rfs(2π*c./ω)
    MarcatilliMode(a, n, m, kind, ϕ, coren, cladn, loss=loss)
end

dimlimits(m::MarcatilliMode) = ((0.0, 0.0), (m.a, 2π))

function β(m::MarcatilliMode, ω)
    χ = m.coren.(ω).^2 .- 1
    return @. ω/c*(1 + χ/2 - c^2*m.unm^2/(2*ω^2*m.a^2))
end

function αMarcatilli(m::MarcatilliMode, ω)
    ν = m.cladn.(ω)
    if m.kind == :HE
        vp = @. (ν^2 + 1)/(2*real(sqrt(Complex(ν^2-1))))
    elseif m.kind == :TE
        vp = @. 1/(real(sqrt(Complex(ν^2-1))))
    elseif m.kind == :TM
        vp = @. ν^2/(real(sqrt(Complex(ν^2-1))))
    else
        error("kind must be :TE, :TM or :HE")
    end
    return @. 2*(c^2 * m.unm^2)/(m.a^3 * ω^2) * vp
end

function α(m::MarcatilliMode, ω)
    m.loss(m, ω)
end

# we use polar coords, so xs = (r, θ)
function field(m::MarcatilliMode)
    if m.kind == :HE
        return (r, θ) -> besselj(m.n-1, r*m.unm/m.a) .* SVector(cos(θ)*sin(m.n*(θ + m.ϕ)) - sin(θ)*cos(m.n*(θ + m.ϕ)),
                                                          sin(θ)*sin(m.n*(θ + m.ϕ)) + cos(θ)*cos(m.n*(θ + m.ϕ)))
    elseif m.kind == :TE
        return (r, θ) -> besselj(1, r*m.unm/m.a) .* SVector(-sin(θ), cos(θ))
    elseif m.kind == :TM
        return (r, θ) -> besselj(1, r*m.unm/m.a) .* SVector(cos(θ), sin(θ))
    end
end

end
