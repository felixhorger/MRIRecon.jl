
"""
	plan_sensitivities(sensitivities::Union{AbstractMatrix{<: Number}, AbstractArray{<: Number, 3}}) = S

	sensitivities[spatial dimensions..., channels]
	num_x = all spatial dimensions
"""
function plan_sensitivities(
	sensitivities::AbstractArray{<: Number, N},
	num_x::Integer,
	num_dynamic::Integer
) where N
	# Get dimensions
	shape = size(sensitivities)
	num_channels = shape[N]
	input_dimension = num_x * num_dynamic
	output_dimension = input_dimension * num_channels

	# Reshape
	sensitivities = reshape(sensitivities, num_x, num_channels, 1)
	conj_sensitivities = conj.(sensitivities)

	S = LinearMap{ComplexF64}(
		x::AbstractVector{<: Complex} -> begin
			Sx = sensitivities .* reshape(x, num_x, 1, num_dynamic)
			vec(Sx)
		end,
		y::AbstractVector{<: Complex} -> begin
			y = reshape(y, num_x, num_channels, num_dynamic)
			SHy = sum(conj_sensitivities .* y; dims=2)
			vec(SHy)
		end,
		output_dimension, input_dimension
	)
	return S
end

"""
	plan_PSF(F::LinearMap, M::LinearMap [, S::LinearMap])
"""
plan_psf(M::LinearMap, F::LinearMap) = F' * M * F
plan_psf(M::LinearMap, F::LinearMap, S::LinearMap) = S' * F' * M * F * S


"""
	A must be callable, taking a vector to compute the matrix vector product
	shape is spatial
	return psf[spatial dims..., dynamic_out, dynamic_in]
"""
function compute_psf(
	A,
	shape::NTuple{N, Integer},
	num_dynamic::Integer;
	fov_scale::Integer=1,
	fftshifted::Bool=false
) where N

	if fftshifted
		centre = ntuple(_ -> 1, Val(N))
	else
		centre = shape .÷ 2
	end
	psf = Array{ComplexF64, N+2}(undef, (fov_scale .* shape)..., num_dynamic, num_dynamic) # out in
	δ = zeros(ComplexF64, prod(shape) * num_dynamic)
	idx = LinearIndices((shape..., num_dynamic))
	colons = ntuple(_ -> :, N+1)
	@views for t = 1:num_dynamic
		i = idx[centre..., t]
		δ[i] = 1 # Set Dirac-delta
		psf[colons..., t] = A(δ)
		δ[i] = 0 # Unset
	end
	return psf
end

