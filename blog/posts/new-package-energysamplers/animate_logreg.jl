function animate_logreg(; steps::Int=500, opt=SGLD(), n=250)
    Random.seed!(1)

    paramvec(θ) = reduce(hcat, cpu(θ))
    model = gpu(Dense(length(features), 1, sigmoid))
    θ = Flux.params(model)
    θ₀ = paramvec(θ)

    predict(x; thres=0.5) = model(x) .> thres
    accuracy(x, y) = mean(cpu(predict(x)) .== cpu(y))

    loss(yhat, y) = Flux.binarycrossentropy(yhat, y)
    avg_loss(yhat, y) = mean(loss(yhat, y))
    trainloss() = avg_loss(model(train_X), train_y)
    testloss() = avg_loss(model(test_X), test_y)

    trainlosses = [cpu(trainloss()); zeros(steps)]
    testlosses = [cpu(testloss()); zeros(steps)]
    weights = [cpu(θ₀); zeros(steps, length(θ₀))]

    opt_state = Flux.setup(opt, model)

    for t in 1:steps
        for data in train_set
            input, label = data

            # Calculate the gradient of the objective
            # with respect to the parameters within the model:
            grads = Flux.gradient(model) do m
                result = m(input)
                loss(result, label)
            end

            Flux.update!(opt_state, model, grads[1])
        end

        # Bookkeeping
        weights[t+1, :] = cpu(paramvec(θ))
        trainlosses[t+1] = cpu(trainloss())
        testlosses[t+1] = cpu(testloss())

    end

    T = size(weights, 1) - 1
    anim = @animate for t in (n+2):T
        plts = []
        _start = maximum([2, t - n + 1])
        println("Iteration $t of $steps")
        for (i, name) in enumerate(["Student" "Balance" "Income" "Intercept"])
            x = weights[_start:t, i]
            plt = histogram(
                x, title=name, size=(500, 500), label="", color=i,
                xlims=extrema(weights[:,i]) .* 1.1,
            )
            push!(plts, plt)
        end
        plot(plts..., size=(1000, 1000), plot_title="Iteration $t of $steps")
    end

    return anim 
end