x = [0.29655668731713436
0.4012832851663651
-1.0611728986687934
0.027890845668247413
0.17287751342253802
12.070228321665113
3.8893943097551804]
optim_problem(x)

# Vary first parameter between 0 and 1
α_vals =  0.01:0.025:0.99 |> collect
obj_funct_1 = optim_problem.( [ [i , x[2:end]...] for i in α_vals ]  )
p1 = plot(α_vals[1:20], obj_funct_1[1:20], xlabel = "α", ylabel = "G")
vline!([x[1]], color =2)

σ_vals =  0.01:0.025:0.99 |> collect
obj_funct_2 = optim_problem.( [ [x[1], i , x[3:end]...] for i in σ_vals ]  )
p2 = plot(σ_vals[10:20], obj_funct_2[10:20], xlabel = "σ", ylabel = "G")
vline!([x[2]], color =2)

ρ_vals =  -1.5:0.025:-0.5 |> collect
obj_funct_3 = optim_problem.( [ [x[1], x[2], i , x[4:end]...] for i in ρ_vals ]  )
p3 = plot(ρ_vals, obj_funct_3, xlabel = "ρ", ylabel = "G")
vline!([x[3]], color =2)

μ_vals =  0.01:0.0025:0.1 |> collect
obj_funct_4 = optim_problem.( [ [x[1], x[2], x[3], i , x[5:end]...] for i in μ_vals ]  )
p4 = plot(μ_vals, obj_funct_4, xlabel = "μ", ylabel = "G")
vline!([x[4]], color =2)

λ_vals =  0.1:0.005:0.3 |> collect
obj_funct_5 = optim_problem.( [ [x[1], x[2], x[3], x[4], i , x[6:end]...] for i in λ_vals ]  )
p5 = plot(λ_vals, obj_funct_5, xlabel = "λ", ylabel = "G")
vline!([x[5]], color =2)

φ_ℓ = 6:0.25:15 |> collect
obj_funct_6 = optim_problem.( [ [x[1], x[2], x[3], x[4], x[5], i , x[7:end]...] for i in φ_ℓ ]  )
p6 = plot(φ_ℓ, obj_funct_6, xlabel = "φℓ", ylabel = "G")
vline!([x[6]], color =2)

φ_h = 3.5:0.025:4.5 |> collect
obj_funct_7 = optim_problem.( [ [x[1], x[2], x[3], x[4], x[5], x[6], i , x[8:end]...] for i in φ_h ]  )
p7 = plot(φ_h, obj_funct_7, xlabel = "φh", ylabel = "G")
vline!([x[7]], color =2)

plot(p1, p2, p3, p4, p5, p6, p7)