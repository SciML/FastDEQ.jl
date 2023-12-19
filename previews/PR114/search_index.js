var documenterSearchIndex = {"docs":
[{"location":"references/#References","page":"References","title":"References","text":"","category":"section"},{"location":"references/","page":"References","title":"References","text":"Bai, S.; Kolter, J. Z. and Koltun, V. (2019). Deep Equilibrium Models, arXiv:1909.01377 [cs, stat]. Accessed on Sep 13, 2021, arXiv: 1909.01377.\n\n\n\nBai, S.; Koltun, V. and Kolter, J. Z. (2020). Multiscale Deep Equilibrium Models, arXiv:2006.08656 [cs, stat]. Accessed on Sep 14, 2021, arXiv: 2006.08656.\n\n\n\nPal, A.; Edelman, A. and Rackauckas, C. (2022). Mixing implicit and explicit deep learning with skip DEQs and infinite time neural odes (continuous DEQs). Training 4, 5.\n\n\n\n","category":"page"},{"location":"api/#Deep-Equilibrium-Models","page":"API References","title":"Deep Equilibrium Models","text":"","category":"section"},{"location":"api/","page":"API References","title":"API References","text":"(Bai et al., 2019) introduced Discrete Deep Equilibrium Models which drives a Discrete Dynamical System to its steady-state. (Pal et al., 2022) extends this framework to Continuous Dynamical Systems which converge to the steady-stable in a more stable fashion. For a detailed discussion refer to (Pal et al., 2022).","category":"page"},{"location":"api/","page":"API References","title":"API References","text":"To construct a continuous DEQ, any ODE solver compatible with DifferentialEquations.jl API can be passed as the solver. To construct a discrete DEQ, any root finding algorithm compatible with NonlinearSolve.jl API can be passed as the solver.","category":"page"},{"location":"api/#Standard-Models","page":"API References","title":"Standard Models","text":"","category":"section"},{"location":"api/","page":"API References","title":"API References","text":"DeepEquilibriumNetwork\nSkipDeepEquilibriumNetwork","category":"page"},{"location":"api/#DeepEquilibriumNetworks.DeepEquilibriumNetwork","page":"API References","title":"DeepEquilibriumNetworks.DeepEquilibriumNetwork","text":"DeepEquilibriumNetwork(model, solver; init = missing, jacobian_regularization=nothing,\n    problem_type::Type{pType}=SteadyStateProblem{false}, kwargs...)\n\nDeep Equilibrium Network as proposed in (Bai et al., 2019) and (Pal et al., 2022).\n\nArguments\n\nmodel: Neural Network.\nsolver: Solver for the rootfinding problem. ODE Solvers and Nonlinear Solvers are both supported.\n\nKeyword Arguments\n\ninit: Initial Condition for the rootfinding problem. If nothing, the initial condition is set to zero(x). If missing, the initial condition is set to WrappedFunction(zero). In other cases the initial condition is set to init(x, ps, st).\njacobian_regularization: Must be one of nothing, AutoFiniteDiff or AutoZygote.\nproblem_type: Provides a way to simulate a Vanilla Neural ODE by setting the problem_type to ODEProblem. By default, the problem type is set to SteadyStateProblem.\nkwargs: Additional Parameters that are directly passed to SciMLBase.solve.\n\nExample\n\njulia> using DeepEquilibriumNetworks, Lux, Random, OrdinaryDiffEq\n\njulia> model = DeepEquilibriumNetwork(Parallel(+, Dense(2, 2; use_bias=false),\n               Dense(2, 2; use_bias=false)), VCABM3())\nDeepEquilibriumNetwork(\n    model = Parallel(\n        +\n        Dense(2 => 2, bias=false),      # 4 parameters\n        Dense(2 => 2, bias=false),      # 4 parameters\n    ),\n    init = WrappedFunction(Base.Fix1{typeof(DeepEquilibriumNetworks.__zeros_init), Nothing}(DeepEquilibriumNetworks.__zeros_init, nothing)),\n)         # Total: 8 parameters,\n          #        plus 0 states.\n\njulia> rng = Random.default_rng()\nTaskLocalRNG()\n\njulia> ps, st = Lux.setup(rng, model);\n\njulia> model(ones(Float32, 2, 1), ps, st);\n\n\nSee also: SkipDeepEquilibriumNetwork, MultiScaleDeepEquilibriumNetwork, MultiScaleSkipDeepEquilibriumNetwork.\n\n\n\n\n\n","category":"type"},{"location":"api/#DeepEquilibriumNetworks.SkipDeepEquilibriumNetwork","page":"API References","title":"DeepEquilibriumNetworks.SkipDeepEquilibriumNetwork","text":"SkipDeepEquilibriumNetwork(model, [init=nothing,] solver; kwargs...)\n\nSkip Deep Equilibrium Network as proposed in (Pal et al., 2022). Alias which creates a DeepEquilibriumNetwork with init kwarg set to passed value.\n\n\n\n\n\n","category":"function"},{"location":"api/#MultiScale-Models","page":"API References","title":"MultiScale Models","text":"","category":"section"},{"location":"api/","page":"API References","title":"API References","text":"MultiScaleDeepEquilibriumNetwork\nMultiScaleSkipDeepEquilibriumNetwork\nMultiScaleNeuralODE","category":"page"},{"location":"api/#DeepEquilibriumNetworks.MultiScaleDeepEquilibriumNetwork","page":"API References","title":"DeepEquilibriumNetworks.MultiScaleDeepEquilibriumNetwork","text":"MultiScaleDeepEquilibriumNetwork(main_layers::Tuple, mapping_layers::Matrix,\n    post_fuse_layer::Union{Nothing, Tuple}, solver,\n    scales::NTuple{N, NTuple{L, Int64}}; kwargs...)\n\nMulti Scale Deep Equilibrium Network as proposed in (Bai et al., 2020).\n\nArguments\n\nmain_layers: Tuple of Neural Networks. Each Neural Network is applied to the corresponding scale.\nmapping_layers: Matrix of Neural Networks. Each Neural Network is applied to the corresponding scale and the corresponding layer.\npost_fuse_layer: Neural Network applied to the fused output of the main layers.\nsolver: Solver for the rootfinding problem. ODE Solvers and Nonlinear Solvers are both supported.\nscales: Scales of the Multi Scale DEQ. Each scale is a tuple of integers. The length of the tuple is the number of layers in the corresponding main layer.\n\nFor keyword arguments, see DeepEquilibriumNetwork.\n\nExample\n\njulia> using DeepEquilibriumNetworks, Lux, Random, NonlinearSolve\n\njulia> main_layers = (Parallel(+, Dense(4 => 4, tanh; use_bias=false),\n               Dense(4 => 4, tanh; use_bias=false)), Dense(3 => 3, tanh), Dense(2 => 2, tanh),\n           Dense(1 => 1, tanh))\n(Parallel(), Dense(3 => 3, tanh_fast), Dense(2 => 2, tanh_fast), Dense(1 => 1, tanh_fast))\n\njulia> mapping_layers = [NoOpLayer() Dense(4 => 3, tanh) Dense(4 => 2, tanh) Dense(4 => 1, tanh);\n           Dense(3 => 4, tanh) NoOpLayer() Dense(3 => 2, tanh) Dense(3 => 1, tanh);\n           Dense(2 => 4, tanh) Dense(2 => 3, tanh) NoOpLayer() Dense(2 => 1, tanh);\n           Dense(1 => 4, tanh) Dense(1 => 3, tanh) Dense(1 => 2, tanh) NoOpLayer()]\n4×4 Matrix{LuxCore.AbstractExplicitLayer}:\n NoOpLayer()               …  Dense(4 => 1, tanh_fast)\n Dense(3 => 4, tanh_fast)     Dense(3 => 1, tanh_fast)\n Dense(2 => 4, tanh_fast)     Dense(2 => 1, tanh_fast)\n Dense(1 => 4, tanh_fast)     NoOpLayer()\n\njulia> model = MultiScaleDeepEquilibriumNetwork(main_layers, mapping_layers, nothing,\n           NewtonRaphson(), ((4,), (3,), (2,), (1,)))\nDeepEquilibriumNetwork(\n    model = MultiScaleInputLayer{scales = 4}(\n        model = Chain(\n            layer_1 = Parallel(\n                layer_1 = Parallel(\n                    +\n                    Dense(4 => 4, tanh_fast, bias=false),  # 16 parameters\n                    Dense(4 => 4, tanh_fast, bias=false),  # 16 parameters\n                ),\n                layer_2 = Dense(3 => 3, tanh_fast),  # 12 parameters\n                layer_3 = Dense(2 => 2, tanh_fast),  # 6 parameters\n                layer_4 = Dense(1 => 1, tanh_fast),  # 2 parameters\n            ),\n            layer_2 = BranchLayer(\n                layer_1 = Parallel(\n                    +\n                    NoOpLayer(),\n                    Dense(3 => 4, tanh_fast),  # 16 parameters\n                    Dense(2 => 4, tanh_fast),  # 12 parameters\n                    Dense(1 => 4, tanh_fast),  # 8 parameters\n                ),\n                layer_2 = Parallel(\n                    +\n                    Dense(4 => 3, tanh_fast),  # 15 parameters\n                    NoOpLayer(),\n                    Dense(2 => 3, tanh_fast),  # 9 parameters\n                    Dense(1 => 3, tanh_fast),  # 6 parameters\n                ),\n                layer_3 = Parallel(\n                    +\n                    Dense(4 => 2, tanh_fast),  # 10 parameters\n                    Dense(3 => 2, tanh_fast),  # 8 parameters\n                    NoOpLayer(),\n                    Dense(1 => 2, tanh_fast),  # 4 parameters\n                ),\n                layer_4 = Parallel(\n                    +\n                    Dense(4 => 1, tanh_fast),  # 5 parameters\n                    Dense(3 => 1, tanh_fast),  # 4 parameters\n                    Dense(2 => 1, tanh_fast),  # 3 parameters\n                    NoOpLayer(),\n                ),\n            ),\n        ),\n    ),\n    init = WrappedFunction(Base.Fix1{typeof(DeepEquilibriumNetworks.__zeros_init), Val{((4,), (3,), (2,), (1,))}}(DeepEquilibriumNetworks.__zeros_init, Val{((4,), (3,), (2,), (1,))}())),\n)         # Total: 152 parameters,\n          #        plus 0 states.\n\njulia> rng = Random.default_rng()\nTaskLocalRNG()\n\njulia> ps, st = Lux.setup(rng, model);\n\njulia> x = rand(rng, Float32, 4, 12);\n\njulia> model(x, ps, st);\n\n\n\n\n\n\n","category":"function"},{"location":"api/#DeepEquilibriumNetworks.MultiScaleSkipDeepEquilibriumNetwork","page":"API References","title":"DeepEquilibriumNetworks.MultiScaleSkipDeepEquilibriumNetwork","text":"MultiScaleSkipDeepEquilibriumNetwork(main_layers::Tuple, mapping_layers::Matrix,\n    post_fuse_layer::Union{Nothing, Tuple}, [init = nothing,] solver,\n    scales::NTuple{N, NTuple{L, Int64}}; kwargs...)\n\nSkip Multi Scale Deep Equilibrium Network as proposed in (Pal et al., 2022). Alias which creates a MultiScaleDeepEquilibriumNetwork with init kwarg set to passed value.\n\nIf init is not passed, it creates a MultiScale Regularized Deep Equilibrium Network.\n\n\n\n\n\n","category":"function"},{"location":"api/#DeepEquilibriumNetworks.MultiScaleNeuralODE","page":"API References","title":"DeepEquilibriumNetworks.MultiScaleNeuralODE","text":"MultiScaleNeuralODE(args...; kwargs...)\n\nSame arguments as MultiScaleDeepEquilibriumNetwork but sets problem_type to ODEProblem{false}.\n\n\n\n\n\n","category":"function"},{"location":"api/#Solution","page":"API References","title":"Solution","text":"","category":"section"},{"location":"api/","page":"API References","title":"API References","text":"DeepEquilibriumSolution","category":"page"},{"location":"api/#DeepEquilibriumNetworks.DeepEquilibriumSolution","page":"API References","title":"DeepEquilibriumNetworks.DeepEquilibriumSolution","text":"DeepEquilibriumSolution(z_star, u₀, residual, jacobian_loss, nfe, solution)\n\nStores the solution of a DeepEquilibriumNetwork and its variants.\n\nFields\n\nz_star: Steady-State or the value reached due to maxiters\nu0: Initial Condition\nresidual: Difference of the z^* and f(z^* x)\njacobian_loss: Jacobian Stabilization Loss (see individual networks to see how it can be computed)\nnfe: Number of Function Evaluations\noriginal: Original Internal Solution\n\n\n\n\n\n","category":"type"},{"location":"tutorials/reduced_dim_deq/#Modelling-Equilibrium-Models-with-Reduced-State-Size","page":"Modelling Equilibrium Models with Reduced State Size","title":"Modelling Equilibrium Models with Reduced State Size","text":"","category":"section"},{"location":"tutorials/reduced_dim_deq/","page":"Modelling Equilibrium Models with Reduced State Size","title":"Modelling Equilibrium Models with Reduced State Size","text":"This Tutorial is currently under preparation. Check back soon.","category":"page"},{"location":"tutorials/basic_mnist_deq/#Training-a-Simple-MNIST-Classifier-using-Deep-Equilibrium-Models","page":"Training a Simple MNIST Classifier using Deep Equilibrium Models","title":"Training a Simple MNIST Classifier using Deep Equilibrium Models","text":"","category":"section"},{"location":"tutorials/basic_mnist_deq/","page":"Training a Simple MNIST Classifier using Deep Equilibrium Models","title":"Training a Simple MNIST Classifier using Deep Equilibrium Models","text":"We will train a simple Deep Equilibrium Model on MNIST. First we load a few packages.","category":"page"},{"location":"tutorials/basic_mnist_deq/","page":"Training a Simple MNIST Classifier using Deep Equilibrium Models","title":"Training a Simple MNIST Classifier using Deep Equilibrium Models","text":"using DeepEquilibriumNetworks, SciMLSensitivity, Lux, NonlinearSolve, OrdinaryDiffEq,\n    Statistics, Random, Optimization, OptimizationOptimisers, LuxCUDA\nusing MLDatasets: MNIST\nusing MLDataUtils: LabelEnc, convertlabel, stratifiedobs\n\nCUDA.allowscalar(false)\nENV[\"DATADEPS_ALWAYS_ACCEPT\"] = true","category":"page"},{"location":"tutorials/basic_mnist_deq/","page":"Training a Simple MNIST Classifier using Deep Equilibrium Models","title":"Training a Simple MNIST Classifier using Deep Equilibrium Models","text":"Setup device functions from Lux. See GPU Management for more details.","category":"page"},{"location":"tutorials/basic_mnist_deq/","page":"Training a Simple MNIST Classifier using Deep Equilibrium Models","title":"Training a Simple MNIST Classifier using Deep Equilibrium Models","text":"const cdev = cpu_device()\nconst gdev = gpu_device()","category":"page"},{"location":"tutorials/basic_mnist_deq/","page":"Training a Simple MNIST Classifier using Deep Equilibrium Models","title":"Training a Simple MNIST Classifier using Deep Equilibrium Models","text":"We can now construct our dataloader.","category":"page"},{"location":"tutorials/basic_mnist_deq/","page":"Training a Simple MNIST Classifier using Deep Equilibrium Models","title":"Training a Simple MNIST Classifier using Deep Equilibrium Models","text":"function onehot(labels_raw)\n    return convertlabel(LabelEnc.OneOfK, labels_raw, LabelEnc.NativeLabels(collect(0:9)))\nend\n\nfunction loadmnist(batchsize)\n    # Load MNIST\n    mnist = MNIST(; split=:train)\n    imgs, labels_raw = mnist.features, mnist.targets\n    # Process images into (H,W,C,BS) batches\n    x_train = Float32.(reshape(imgs, size(imgs, 1), size(imgs, 2), 1, size(imgs, 3))) |>\n              gdev\n    x_train = batchview(x_train, batchsize)\n    # Onehot and batch the labels\n    y_train = onehot(labels_raw) |> gdev\n    y_train = batchview(y_train, batchsize)\n    return x_train, y_train\nend","category":"page"},{"location":"#DeepEquilibriumNetworks.jl","page":"Home","title":"DeepEquilibriumNetworks.jl","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"DeepEquilibriumNetworks.jl is a framework built on top of DifferentialEquations.jl and Lux.jl, enabling the efficient training and inference for Deep Equilibrium Networks (Infinitely Deep Neural Networks).","category":"page"},{"location":"#Installation","page":"Home","title":"Installation","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"To install DeepEquilibriumNetworks.jl, use the Julia package manager:","category":"page"},{"location":"","page":"Home","title":"Home","text":"using Pkg\nPkg.add(\"DeepEquilibriumNetworks\")","category":"page"},{"location":"#Quick-start","page":"Home","title":"Quick-start","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"using DeepEquilibriumNetworks, Lux, Random, NonlinearSolve, Zygote, SciMLSensitivity\nusing LuxCUDA  # For NVIDIA GPU support\n\nseed = 0\nrng = Random.default_rng()\nRandom.seed!(rng, seed)\n\nmodel = Chain(Dense(2 => 2),\n    DeepEquilibriumNetwork(Parallel(+, Dense(2 => 2; use_bias=false),\n            Dense(2 => 2; use_bias=false)), NewtonRaphson()))\n\ngdev = gpu_device()\ncdev = cpu_device()\n\nps, st = Lux.setup(rng, model) |> gdev\nx = rand(rng, Float32, 2, 3) |> gdev\ny = rand(rng, Float32, 2, 3) |> gdev\n\nres, st_ = model(x, ps, st)\nst_.layer_2.solution","category":"page"},{"location":"","page":"Home","title":"Home","text":"gs = only(Zygote.gradient(p -> sum(abs2, first(model(x, p, st)) .- y), ps))","category":"page"},{"location":"#Citation","page":"Home","title":"Citation","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"If you are using this project for research or other academic purposes, consider citing our paper:","category":"page"},{"location":"","page":"Home","title":"Home","text":"@article{pal2022continuous,\n  title={Continuous Deep Equilibrium Models: Training Neural ODEs Faster by Integrating Them to Infinity},\n  author={Pal, Avik and Edelman, Alan and Rackauckas, Christopher},\n  booktitle={2023 IEEE High Performance Extreme Computing Conference (HPEC)}, \n  year={2023}\n}","category":"page"},{"location":"","page":"Home","title":"Home","text":"For specific algorithms, check the respective documentations and cite the corresponding papers.","category":"page"},{"location":"#Contributing","page":"Home","title":"Contributing","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"Please refer to the SciML ColPrac: Contributor's Guide on Collaborative Practices for Community Packages for guidance on PRs, issues, and other matters relating to contributing to SciML.\nSee the SciML Style Guide for common coding practices and other style decisions.\nThere are a few community forums:\nThe #diffeq-bridged and #sciml-bridged channels in the Julia Slack\nThe #diffeq-bridged and #sciml-bridged channels in the Julia Zulip\nOn the Julia Discourse forums\nSee also SciML Community page","category":"page"},{"location":"#Reproducibility","page":"Home","title":"Reproducibility","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"<details><summary>The documentation of this SciML package was built using these direct dependencies,</summary>","category":"page"},{"location":"","page":"Home","title":"Home","text":"using Pkg # hide\nPkg.status() # hide","category":"page"},{"location":"","page":"Home","title":"Home","text":"</details>","category":"page"},{"location":"","page":"Home","title":"Home","text":"<details><summary>and using this machine and Julia version.</summary>","category":"page"},{"location":"","page":"Home","title":"Home","text":"using InteractiveUtils # hide\nversioninfo() # hide","category":"page"},{"location":"","page":"Home","title":"Home","text":"</details>","category":"page"},{"location":"","page":"Home","title":"Home","text":"<details><summary>A more complete overview of all dependencies and their versions is also provided.</summary>","category":"page"},{"location":"","page":"Home","title":"Home","text":"using Pkg # hide\nPkg.status(; mode=PKGMODE_MANIFEST) # hide","category":"page"},{"location":"","page":"Home","title":"Home","text":"</details>","category":"page"},{"location":"","page":"Home","title":"Home","text":"using TOML\nusing Markdown\nversion = TOML.parse(read(\"../../Project.toml\", String))[\"version\"]\nname = TOML.parse(read(\"../../Project.toml\", String))[\"name\"]\nlink_manifest = \"https://github.com/SciML/\" *\n                name *\n                \".jl/tree/gh-pages/v\" *\n                version *\n                \"/assets/Manifest.toml\"\nlink_project = \"https://github.com/SciML/\" *\n               name *\n               \".jl/tree/gh-pages/v\" *\n               version *\n               \"/assets/Project.toml\"\nMarkdown.parse(\"\"\"You can also download the\n[manifest]($link_manifest)\nfile and the\n[project]($link_project)\nfile.\n\"\"\")","category":"page"}]
}
