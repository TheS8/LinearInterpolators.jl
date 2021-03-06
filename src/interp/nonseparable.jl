#
# interp/nonseparable.jl --
#
# Non-separable multidimensional interpolation.
#
#------------------------------------------------------------------------------
#
# This file is part of the LinearInterpolators package licensed under the MIT
# "Expat" License.
#
# Copyright (C) 2016-2018, Éric Thiébaut.
#

# FIXME: if axes are aligned, use separable interpolation.

# Provide default Direct operation.
function apply!(dst::AbstractArray{T,2},
                ker::Kernel{T,S,<:Boundaries},
                R::AffineTransform2D{T},
                src::AbstractArray{T,2}) where {T,S}
    apply!(dst, Direct, ker, R, src)
end
function apply!(dst::AbstractArray{T,2},
                ker1::Kernel{T,S1,<:Boundaries},
                ker2::Kernel{T,S2,<:Boundaries},
                R::AffineTransform2D{T},
                src::AbstractArray{T,2}) where {T,S1,S2}
    return apply!(dst, Direct, ker1, ker2, R, src)
end


# Provide default α=1 and β=0 factors.
function apply!(dst::AbstractArray{T,2},
                ::Type{P},
                ker::Kernel{T,S,<:Boundaries},
                R::AffineTransform2D{T},
                src::AbstractArray{T,2}) where {P<:Operations,T,S}
    return apply!(1, P, ker, R, src, 0, dst)
end
function apply!(dst::AbstractArray{T,2},
                ::Type{P},
                ker1::Kernel{T,S1,<:Boundaries},
                ker2::Kernel{T,S2,<:Boundaries},
                R::AffineTransform2D{T},
                src::AbstractArray{T,2}) where {P<:Operations,T,S1,S2}
    return apply!(1, P, ker1, ker2, R, src, 0, dst)
end

# Provide default pair of kernels (ker1,ker2) = ker.
function apply!(α::Real,
                ::Type{P},
                ker::Kernel{T,S,<:Boundaries},
                R::AffineTransform2D{T},
                src::AbstractArray{T,2},
                β::Real,
                dst::AbstractArray{T,2}) where {P<:Operations,
                                                T<:AbstractFloat,S}
    return apply!(α, P, ker, ker, R, src, β, dst)
end

@generated function apply!(α::Real,
                           ::Type{Direct},
                           ker1::Kernel{T,S1,<:Boundaries},
                           ker2::Kernel{T,S2,<:Boundaries},
                           R::AffineTransform2D{T},
                           src::AbstractArray{T,2},
                           β::Real,
                           dst::AbstractArray{T,2}) where {T<:AbstractFloat,
                                                           S1,S2}
    # Generate peices of code.
    J1, W1 = Meta.make_varlist(:_j1, S1), Meta.make_varlist(:_w1, S1)
    J2, W2 = Meta.make_varlist(:_j2, S2), Meta.make_varlist(:_w2, S2)
    code2 = (:( pos2 = convert(T, i2)  ),
             :( off1 = R.xy*pos2 + R.x ),
             :( off2 = R.yy*pos2 + R.y ))
    code1 = (:( pos1 = convert(T, i1)  ),
             Meta.generate_getcoefs(J1, W1, :ker1, :lim1, :(R.xx*pos1 + off1)),
             Meta.generate_getcoefs(J2, W2, :ker2, :lim2, :(R.yx*pos1 + off2)))
    expr = Meta.generate_interp_expr(:src, J1, W1, J2, W2)

    quote
        if α == 0
            # Just scale destination.
            vscale!(dst, β)
        else
            # Get dimensions and limits.
            n1, n2 = size(dst)
            lim1 = limits(ker1, size(src, 1))
            lim2 = limits(ker2, size(src, 2))

            # Apply the operator considering the specific values of α and β.
            if α == 1 && β == 0
                for i2 in 1:n2
                    $(code2...)
                    @inbounds for i1 in 1:n1
                        $(code1...)
                        dst[i1,i2] = $expr
                    end
                end
            else
                alpha = convert(T, α)
                beta = convert(T, β)
                for i2 in 1:n2
                    $(code2...)
                    @inbounds for i1 in 1:n1
                        $(code1...)
                        dst[i1,i2] = $expr*alpha + dst[i1,i2]*beta
                    end
                end
            end
        end
        return dst
    end
end

@generated function apply!(α::Real,
                           ::Type{Adjoint},
                           ker1::Kernel{T,S1,<:Boundaries},
                           ker2::Kernel{T,S2,<:Boundaries},
                           R::AffineTransform2D{T},
                           src::AbstractArray{T,2},
                           β::Real,
                           dst::AbstractArray{T,2}) where{T<:AbstractFloat,
                                                          S1,S2}
    # Generate pieces of code.
    J1, W1 = Meta.make_varlist(:_j1, S1), Meta.make_varlist(:_w1, S1)
    J2, W2 = Meta.make_varlist(:_j2, S2), Meta.make_varlist(:_w2, S2)
    temp = Meta.make_varlist(:_tmp, 1:S2)
    code2 = (:( pos2 = convert(T, i2)  ),
             :( off1 = R.xy*pos2 + R.x ),
             :( off2 = R.yy*pos2 + R.y ))
    code1 = [:( pos1 = convert(T, i1)  ),
             Meta.generate_getcoefs(J1, W1, :ker1, :lim1, :(R.xx*pos1 + off1)),
             Meta.generate_getcoefs(J2, W2, :ker2, :lim2, :(R.yx*pos1 + off2))]
    for i2 in 1:S2
        push!(code1, :( $(temp[i2]) = $(W2[i2])*val ))
        for i1 in 1:S1
            push!(code1, :(
                dst[$(J1[i1]),$(J2[i2])] += $(W1[i1])*$(temp[i2])
            ))
        end
    end

    quote
        # Pres-scale or zero destination.
        vscale!(dst, β)

        # Get dimensions and limits.
        n1, n2 = size(src)
        lim1 = limits(ker1, size(dst, 1))
        lim2 = limits(ker2, size(dst, 2))

        # Apply adjoint operator.
        if α == 1
            for i2 in 1:n2
                $(code2...)
                @inbounds for i1 in 1:n1
                    val = src[i1,i2]
                    $(code1...)
                end
            end
        elseif α != 0
            alpha = convert(T, α)
            for i2 in 1:n2
                $(code2...)
                @inbounds for i1 in 1:n1
                    val = alpha*src[i1,i2]
                    $(code1...)
                end
            end
        end
        return dst
    end
end
