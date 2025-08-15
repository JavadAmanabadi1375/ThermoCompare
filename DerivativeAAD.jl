using Clapeyron, SQLite, DataFrames, Statistics, XLSX, PyCall
import PyPlot; const plt = PyPlot
"AAD% of all derivative properties for polar compounds"
"Pure compounds parameters have been reported in the supplementary material of the paper, So please refer to it for more details. The following code is using the basic xlsx 
data base of the Clapeyron, So in order to non existing parameters, you need to defined a user defined xlsx file and pass as a inpout of the main PC-SAFT, SAFT-VR Mie, SAFT-VR MieGV, PCP-SAFT models."
"For more information please refer to the Clapeyron.jl user defined database website"

const R = 8.314  # J/mole*K

function main()
    # Constants and Configuration
    COMPARISON_COMPOUNDS = ["acetone", "2-pentanone", "3-pentanone",
                          "dimethyl ether","diethyl ether", "dipropyl ether", "dibutyl ether",
                          "methylacetate", "ethylacetate", "propylacetate", 
                          "isopropylacetate", "butylacetate"]
    
    PROPERTIES = ["Density", "KT", "Alpha", "Cp", "Cv", "speed", "Miu"]
    db_path = raw"database direction user defined"
    file_path = "Saving AAD% file user defined [AAD.xlsx]"
    table_name = "Polar_compounds"

    # Initialize plot
    plt.clf()
    fig_alph, ax_alph = plt.subplots(figsize=[12, 9])

    # Database setup
    db = SQLite.DB(db_path)
    df = DataFrame(DBInterface.execute(db, "SELECT * FROM '$table_name'"))

    # Property calculation functions mapping
    property_functions = Dict(
        "Density" => (model, P, T) -> molar_density.(model, P, T).* get_mw(db, model.components[1]),
        "KT" => (model, P, T) -> isothermal_compressibility.(model, P, T).*1e10,
        "Alpha" => (model, P, T) -> isobaric_expansivity.(model, P, T).*1e3,
        "Cp" => (model, P, T) -> isobaric_heat_capacity.(model, P, T),
        "Cv" => (model, P, T) -> isochoric_heat_capacity.(model, P, T),
        "speed" => (model, P, T) -> speed_of_sound.(model, P, T),
        "Miu" => (model, P, T) -> joule_thomson_coefficient.(model, P, T).*1e6
    )

    # Model sheet mapping
    sheet_mapping = Dict(
        ("Density", 1) => "M", ("Density", 2) => "T", ("Density", 3) => "AA", ("Density", 4) => "AH",("Density", 5) => "AO",
        ("KT", 1) => "N", ("KT", 2) => "U", ("KT", 3) => "AB", ("KT", 4) => "AI",("KT", 5) => "AP",
        ("Alpha", 1) => "O", ("Alpha", 2) => "V", ("Alpha", 3) => "AC", ("Alpha", 4) => "AJ",("Alpha", 5) => "AQ",
        ("Cp", 1) => "P", ("Cp", 2) => "W", ("Cp", 3) => "AD", ("Cp", 4) => "AK",("Cp", 5) => "AR",
        ("Cv", 1) => "Q", ("Cv", 2) => "X", ("Cv", 3) => "AE", ("Cv", 4) => "AL",("Cv", 5) => "AS",
        ("speed", 1) => "R", ("speed", 2) => "Y", ("speed", 3) => "AF", ("speed", 4) => "AM",("speed", 5) => "AT",
        ("Miu", 1) => "S", ("Miu", 2) => "Z", ("Miu", 3) => "AG", ("Miu", 4) => "AN",("Miu", 5) => "AU"

    )

    # Process each property and compound
    for (prop_idx, property) in enumerate(PROPERTIES)
            refrow=43
        for (comp_idx, compound) in enumerate(COMPARISON_COMPOUNDS)
            cell_no = refrow + (comp_idx - 1)
            # Filter experimental data
            exp_data = filter(row -> row.compound == compound && row.properties == property && row.value != "", df)
            isempty(exp_data) && continue
            
            P = exp_data.pressure .* 1e6  # Pa
            T = exp_data.temperature     # K
            exp_values = exp_data.value
            num_elements = length(exp_values)
            # Create models (Two ways because the is lack of parameters for these two compounds)
            println(compound)
            if compound in ["propylacetate", "isopropylacetate"]
                models=create_models2(compound)
            elseif compound=="dimethyl ether"
                models=create_models3(compound)
            else
                models=create_models1(compound)
            end
            
            # Calculate and compare for each model
            for (i, model) in enumerate(models)
                # Calculate model predictions
                model_values = [property_functions[property](model, P[j], T[j]) for j in eachindex(T)]

                # Filter out NaN/Inf values
                valid_idx = .! (isnan.(model_values) .| isinf.(model_values))
                model_values = model_values[valid_idx]
                exp_values_filtered = exp_values[valid_idx]
                
                # Calculate AAD
                ard = abs.(model_values .- exp_values_filtered)
                aad = 100 * mean(ard ./ abs.(exp_values_filtered))
                
                
                # Write to Excel if there's a sheet mapping
                sheet_key = get(sheet_mapping, (property, i), nothing)
                sheet_keypoint = get(sheet_mapping, (property, 5), nothing)
                if !isnothing(sheet_key)
                    XLSX.openxlsx(file_path, mode="rw") do xf
                        xf[1][sheet_key * "$cell_no"] = aad
                        xf[1][sheet_keypoint * "$cell_no"] = num_elements
                    end
                end
            end
        end
    end
end

function get_mw(db, compound_name)
    query = "SELECT Mw FROM Com_Properties WHERE ComName == '$compound_name'"
    df_mw = DataFrame(DBInterface.execute(db, query))
    isempty(df_mw) ? error("Molecular weight not found for $compound_name") : df_mw.Mw[1] / 1000
end

function create_models1(compound_name)
    # Special cases for Joback ideal model
    special_cases = Dict(
        "butylacetate" => [("butylacetate", ["CH3"=>2, "CH2"=>3, "COO"=>1])],
        "dipropyl ether" => [("dipropyl ether", ["CH3"=>2, "CH2"=>4, "-O- (non-ring)"=>1])],
        "dibutyl ether" => [("dibutyl ether", ["CH3"=>2, "CH2"=>6, "-O- (non-ring)"=>1])],
        "propylacetate" => [("propylacetate", ["CH3"=>2, "CH2"=>2, "COO"=>1])],
        "isopropylacetate" => [("isopropylacetate", ["CH3"=>3, ">CH"=>1, "COO"=>1])]
    )
    
    ideal_model = haskey(special_cases, compound_name) ? 
                 JobackIdeal(special_cases[compound_name]) : 
                 ReidIdeal([compound_name])
    
    return [
        PCSAFT([compound_name]; idealmodel=ideal_model),
        PCPSAFT([compound_name]; idealmodel=ideal_model),
        SAFTVRMie([compound_name]; idealmodel=ideal_model),
        SAFTVRMieGV([compound_name]; idealmodel=ideal_model)
    ]
end

function create_models2(compound_name)
    # Special cases for Joback ideal model
    special_cases = Dict(
        "butylacetate" => [("butylacetate", ["CH3"=>2, "CH2"=>3, "COO"=>1])],
        "dipropyl ether" => [("dipropyl ether", ["CH3"=>2, "CH2"=>4, "-O- (non-ring)"=>1])],
        "dibutyl ether" => [("dibutyl ether", ["CH3"=>2, "CH2"=>6, "-O- (non-ring)"=>1])],
        "propylacetate" => [("propylacetate", ["CH3"=>2, "CH2"=>2, "COO"=>1])],
        "isopropylacetate" => [("isopropylacetate", ["CH3"=>3, ">CH-"=>1, "COO"=>1])]
    )
    
    ideal_model = haskey(special_cases, compound_name) ? 
                 JobackIdeal(special_cases[compound_name]) : 
                 ReidIdeal([compound_name])
    
    return [
        PCSAFT([compound_name]; idealmodel=ideal_model),
        PCPSAFT([compound_name]; idealmodel=ideal_model)
    ]
end

function create_models3(compound_name)
    # Special cases for Joback ideal model
    special_cases = Dict(
        "butylacetate" => [("butylacetate", ["CH3"=>2, "CH2"=>3, "COO"=>1])],
        "dipropyl ether" => [("dipropyl ether", ["CH3"=>2, "CH2"=>4, "-O- (non-ring)"=>1])],
        "dibutyl ether" => [("dibutyl ether", ["CH3"=>2, "CH2"=>6, "-O- (non-ring)"=>1])],
        "propylacetate" => [("propylacetate", ["CH3"=>2, "CH2"=>2, "COO"=>1])],
        "isopropylacetate" => [("isopropylacetate", ["CH3"=>3, ">CH-"=>1, "COO"=>1])]
    )
    
    ideal_model = haskey(special_cases, compound_name) ? 
                 JobackIdeal(special_cases[compound_name]) : 
                 ReidIdeal([compound_name])
    
    return [
        PCSAFT([compound_name]; idealmodel=ideal_model),
        PCPSAFT([compound_name]; idealmodel=ideal_model),
        SAFTVRMie([compound_name]; idealmodel=ideal_model)
    ]
end
# Run the main function
main()