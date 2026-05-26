using CSV
using DataFrames
using GLM
using Statistics

const DEFAULT_INPUT_DIR = "./data/proc/ind"

const LABOR_IV_FORMULA = @formula(
    labor ~ trend + K_EQ + K_STR + K_EQ_lagged + K_STR_lagged + Q_lagged
)

function parse_args(args)
    input_dir = DEFAULT_INPUT_DIR
    ind_code = nothing

    i = 1
    while i <= length(args)
        if args[i] == "--ind"
            i == length(args) && error("--ind requires an industry code")
            ind_code = args[i + 1]
            i += 2
        elseif args[i] == "--input-dir"
            i == length(args) && error("--input-dir requires a path")
            input_dir = args[i + 1]
            i += 2
        else
            error("Unknown argument: $(args[i])")
        end
    end

    return input_dir, ind_code
end

function source_files(input_dir::String, ind_code)
    if isnothing(ind_code)
        return sort([
            joinpath(input_dir, f)
            for f in readdir(input_dir)
            if endswith(f, ".csv") && !endswith(f, "_iv.csv")
        ])
    end

    path = joinpath(input_dir, "$(ind_code).csv")
    isfile(path) || error("Industry source file not found: $path")
    return [path]
end

function build_regression_frame(data::DataFrame, labor_col::Symbol)
    n = nrow(data)
    n >= 2 || error("Need at least two rows to construct lagged instruments")

    return DataFrame(
        row_id = 2:n,
        labor = data[2:end, labor_col],
        trend = 1:(n - 1),
        K_EQ = data.K_EQ[2:end],
        K_STR = data.K_STR[2:end],
        K_EQ_lagged = data.K_EQ[1:end-1],
        K_STR_lagged = data.K_STR[1:end-1],
        Q_lagged = data.REL_P_EQ[1:end-1],
    )
end

function predict_labor(data::DataFrame, labor_col::Symbol)
    output = Vector{Union{Missing, Float64}}(undef, nrow(data))
    output .= Float64.(data[:, labor_col])

    reg_data = build_regression_frame(data, labor_col)
    predictor_cols = [:trend, :K_EQ, :K_STR, :K_EQ_lagged, :K_STR_lagged, :Q_lagged]
    complete_predictors = completecases(reg_data[:, predictor_cols])
    complete_model = completecases(reg_data[:, [:labor; predictor_cols]])

    model_data = reg_data[complete_model, :]
    if nrow(model_data) <= length(predictor_cols)
        @warn "Too few complete observations to instrument $labor_col; keeping raw values"
        return Float64.(coalesce.(output, data[:, labor_col]))
    end

    model = lm(LABOR_IV_FORMULA, model_data)
    prediction_data = reg_data[complete_predictors, :]
    predicted = predict(model, prediction_data)

    for (row_id, value) in zip(prediction_data.row_id, predicted)
        output[row_id] = value
    end

    return Float64.(coalesce.(output, data[:, labor_col]))
end

function instrument_labor_file(path::String)
    data = CSV.read(path, DataFrame)
    required = [:YEAR, :L_S, :L_U, :W_S, :W_U, :K_EQ, :K_STR, :REL_P_EQ]
    missing_cols = setdiff(required, Symbol.(names(data)))
    isempty(missing_cols) || error("$(basename(path)) missing required columns: $missing_cols")

    output = copy(data)
    output.L_S_raw = Float64.(data.L_S)
    output.L_U_raw = Float64.(data.L_U)
    output.L_S_iv = predict_labor(data, :L_S)
    output.L_U_iv = predict_labor(data, :L_U)

    # Keep estimation-compatible column names pointed at the instrumented labor
    # series, while preserving raw and IV-specific columns for auditability.
    output.L_S = output.L_S_iv
    output.L_U = output.L_U_iv

    out_path = replace(path, r"\.csv$" => "_iv.csv")
    CSV.write(out_path, output)
    return out_path
end

function main(args=ARGS)
    input_dir, ind_code = parse_args(args)
    outputs = String[]
    for path in source_files(input_dir, ind_code)
        out_path = instrument_labor_file(path)
        push!(outputs, out_path)
        println("wrote $out_path")
    end
    println("instrumented $(length(outputs)) file(s)")
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
