"""
This funcation makes a comprehensive comparison between different EOSs
for polar-compounds, mainly (Esters, Ketones, Ethers)

Reference of models
PC-SAFT, SAFT-VR Mie, SAFT-VR MieGV, PCP-SAFT
Saturation properties AAD%
"""

"Pure compounds parameters have been reported in the supplementary material of the paper, So please refer to it for more details. The following code is using the basic xlsx 
data base of the Clapeyron, So in order to non existing parameters, you need to defined a user defined xlsx file and pass as a inpout of the main PC-SAFT, SAFT-VR Mie, SAFT-VR MieGV, PCP-SAFT models."
"For more information please refer to the Clapeyron.jl user defined database website"
using Clapeyron, PyCall
using SQLite
using DataFrames
using Statistics
using XLSX
import PyPlot; const plt = PyPlot


const  R =8.314 #J/mole*k


Comparison_Compound=["acetone","2-pentanone","3-pentanone",
                     "diethyl ether","dipropyl ether","dibutyl ether",
                     "methylacetate","ethylacetate","butylacetate"]
                    
Properties=["Psat","Rhosat"]
# Read data from database
db_path = raw"database direction user defined"
file_path = "Saving AAD% file user defined [AAD.xlsx]"
db=SQLite.DB(db_path)

plt.clf()
fig_alph, ax_alph = plt.subplots(figsize=[12, 9])
foreach(Properties) do property
    global cellNo=26
    foreach(Comparison_Compound) do CompoundName
        if CompoundName=="butylacetate" || CompoundName=="dipropyl ether" || CompoundName=="dibutyl ether"
            model = JobackIdeal([("butylacetate",["CH3"=>2,"CH2"=>3,"COO"=>1])])
            model = JobackIdeal([("dipropyl ether",["CH3"=>2,"CH2"=>4,"-O- (non-ring)"=>1])])
            model = JobackIdeal([("dibutyl ether",["CH3"=>2,"CH2"=>6,"-O- (non-ring)"=>1])])
        else
            model=ReidIdeal([CompoundName])
        end
        model1 = PCSAFT([CompoundName];idealmodel=model)
        model2 = PCPSAFT([CompoundName];idealmodel=model)
        model3 = SAFTVRMie([CompoundName];idealmodel=model)
        model4 = SAFTVRMieGV([CompoundName];idealmodel=model)
        models = [model1,model2,model3,model4];
        n=length(models)

        TableName=CompoundName
        qs_sat="SELECT * FROM '$TableName'"
        data_sat = SQLite.DBInterface.execute(db, qs_sat)
        df_sat = DataFrames.DataFrame(data_sat)
        T = df_sat.Temperature_k 

        if property =="Rhosat"
            Expdata=df_sat.Density_mol_m3    

        else
            Expdata=df_sat.Pressure_Pa    

        end

        lenT=length(T)

        
        for i=1:n
            Modeldata=[]
            Expdatacopy=copy(Expdata)
            if i==1 && property=="Psat"
                sheetname="G"
            elseif i==2 && property=="Psat"
                sheetname="M"
            elseif i==3 && property=="Psat"
                sheetname="I"
            elseif i==4 && property=="Psat"
                sheetname="K"
            elseif i==1 && property=="Rhosat"
                sheetname="H"
            elseif i==2 && property=="Rhosat"
                sheetname="N"
            elseif i==3 && property=="Rhosat"
                sheetname="J"
            elseif i==4 && property=="Rhosat"
                sheetname="L"
            end

            if property=="Rhosat"
                for j=1:lenT
                        sat = saturation_pressure.(models[i],T[j])
                        append!(Modeldata,1/sat[2])

                end
            else
                for j=1:lenT
                        sat = saturation_pressure.(models[i],T[j])
                        append!(Modeldata,sat[1])
                end             
            end

            # # Find the index of NaN value
            non_nan_indices = [j for (j, x) in enumerate(Modeldata) if (isnan(x) || isinf(x))]
            foreach(reverse(non_nan_indices)) do y
                deleteat!(Modeldata, y)
                deleteat!(Expdatacopy, y)

            end

            # ABSOLUTE RELATIVE DEVIATION
            # Checking the outline data by visualization 
            # ARD = abs.((Modeldata) - (Expdatacopy))
            # if i==1 && property=="Psat" && CompoundName=="3-pentanone" && CompoundName =="2-pentanone"
            #     ax_alph.plot(ARD)
            #     display(plt.gcf())
            # end

            # AVERAGE ABSOLUTE RELATIVE DEVIATION
            AAD = 100 * abs.(mean((ARD ./ abs.(Expdatacopy))))

            XLSX.openxlsx(file_path, mode="rw") do xf
                sheet=xf[1]
                sheet[sheetname*"$cellNo"]=AAD
            end

        end
        global  cellNo += 1
    end
end












