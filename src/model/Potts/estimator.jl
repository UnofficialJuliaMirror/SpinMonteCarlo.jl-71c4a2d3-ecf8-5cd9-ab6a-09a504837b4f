function simple_estimator(model::Potts, T::Real, Js::AbstractArray, _=nothing)
    nsites = numsites(model)
    nbonds = numbonds(model)
    invQ = 1.0/model.Q

    M = 0.0
    @inbounds for s in 1:nsites
        M += ifelse(model.spins[s]==1, 1.0-invQ, -invQ)
    end
    M /= nsites
    E = 0.0
    npara = 0
    @inbounds for b in bonds(model)
        s1, s2 = source(b), target(b)
        E -= ifelse(model.spins[s1] == model.spins[s2], 1.0, 0.0) * Js[bondtype(b)]
        npara += ifelse(model.spins[s1] == model.spins[s2], 1, 0)
    end
    E /= nsites

    res = Measurement()
    res["Magnetization"] = M
    res["|Magnetization|"] = abs(M)
    res["Magnetization^2"] = M^2
    res["Magnetization^4"] = M^4
    res["Energy"] = E
    res["Energy^2"] = E^2
    res["Number of Parallel Bonds"] = npara
    return res
end

@doc raw"""
    improved_estimator(model::Potts, T::Real, Js::AbstractArray, sw::SWInfo)

Returns the following observables as `Dict{String, Any}` using cluster information `sw`

# Observables
- `"Energy"`
    - energy density
- `"Energy^2"`
    - square of energy density
- `"Magnetization"`
    - magnetization density
- `"|Magnetization|"`
    - absolute value of magnetization density
- `"|Magnetization|^2"`
    - square of magnetization density
- `"|Magnetization|^4"`
    - quadruple of magnetization density
- `"Clustersize^2"`
    - ``\sum_c r_c^2 ``, where ``r_c`` is the size density of ``c``-th cluster
- `"Clustersize^4"`
    - ``\sum_c r_c^4 ``
- `"Clustersize^2 Clustersize^2"`
    - ``\sum_{c\ne c'} r_c^2 r_{c'}^2``
"""
function improved_estimator(model::Potts, T::Real, Js::AbstractArray, sw::SWInfo)
    nsites = numsites(model)
    Q = model.Q
    nc = numclusters(sw)
    invV = 1.0/nsites

    # magnetization
    I2 = (Q-1)/(Q*Q)
    I4 = (Q-1)*((Q-1)^3+1)/(Q^5)
    M = 0.0
    M2 = 0.0
    M4 = 0.0
    s2 = -1.0/Q
    s1 = 1.0+s2

    N4 = 0.0
    N2N2 = 0.0
    N2 = 0.0
    for (m,s) in zip(sw.clustersize, sw.clusterspin)
        M += (m*invV) * ifelse(s==1, s1, s2)
        m2 = (m*invV)^2
        N4 += m2*m2
        N2N2 += N2*m2
        N2 += m2
    end
    M4 = I4*N4 + 6*I2*I2*N2N2
    M2 = I2*N2

    # energy
    aJ = abs.(Js)
    mbeta = -1.0/T
    ns = sw.activated_bonds
    As = -aJ ./ expm1.(mbeta.*aJ)
    Ans = ns.*As
    E = 0.0
    E2 = 0.0
    for b in 1:numbondtypes(model)
        E2 += aJ[b]*Ans[b]
        E2 += Ans[b] * As[b]*(ns[b]-1)
        E2 += 2.0*Ans[b]*E
        E += Ans[b]
    end

    E *= -invV
    E2 *= invV*invV

    res = Measurement()
    res["Magnetization"] = M
    res["|Magnetization|"] = abs(M)
    res["Magnetization^2"] = M2
    res["Magnetization^4"] = M4
    res["Energy"] = E
    res["Energy^2"] = E2
    res["Clustersize^2"] = N2
    res["Clustersize^4"] = N4
    res["Clustersize^2 Clustersize^2"] = 2*N2N2

    return res
end

default_estimator(model::Potts, update) = ifelse(update==SW_update!, improved_estimator, simple_estimator)
