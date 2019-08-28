import Test: @test
import Luna: Capillary, Modes
import Luna.PhysData: c

λ = 800e-9
ω = 2π*c/λ
a = 125e-6
m = Capillary.MarcatilliMode(a, :He, 1.0)
@test Capillary.β(m, ω) == Capillary.β(m, λ=λ)
@test isapprox(Capillary.losslength(m, λ=800e-9), 7.0593180702769)
@test isapprox(Capillary.dB_per_m(m, λ=800e-9), 0.6152074146252722)
@test Capillary.dB_per_m(m, λ=800e-9) ≈ 8*Capillary.dB_per_m(Capillary.MarcatilliMode(2a, :He, 1.0), λ=800e-9)

λ = 1e-9 .* collect(range(70, stop=7300, length=128))
ω = 2π*c./λ
@test all(isfinite.(Capillary.β(m, ω)))
@test all(isreal.(Capillary.β(m, ω)))
@test all(isreal.(Capillary.β(Capillary.MarcatilliMode(a, :He, 1.0), ω)))
@test all(isreal.(Capillary.β(Capillary.MarcatilliMode(a, :He, 10.0), ω)))
@test all(isreal.(Capillary.β(Capillary.MarcatilliMode(a, :He, 50.0), ω)))
@test all(isfinite.(Capillary.α(m, ω)))
@test all(isreal.(Capillary.α(m, ω)))

@test abs(1e9*Capillary.zdw(Capillary.MarcatilliMode(a, :He, 0.4)) - 379) < 1
@test abs(1e9*Capillary.zdw(Capillary.MarcatilliMode(75e-6, :He, 5.9)) - 562) < 1

@test Capillary.Aeff(Capillary.MarcatilliMode(75e-6, :He, 1.0)) ≈ 8.42157534886545e-09

m = Modes.DelegatedMode(Capillary.MarcatilliMode(75e-6, :He, 5.9))
@test Modes.Aeff(m) ≈ 8.42157534886545e-09
@test abs(1e9*Modes.zdw(m) - 562) < 1
@test Modes.α(Modes.DelegatedMode(Capillary.MarcatilliMode(75e-6, :He, 1.0), αf=(ω)->0.2), 2e15) == 0.2
@test Modes.α(Modes.DelegatedMode(Capillary.MarcatilliMode(75e-6, :He, 1.0), αf=(ω)->0.2), λ=800e-9) == 0.2
