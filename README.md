Overview

This repository provides scripts and data for evaluating the performance of SAFT-type equations of state on pure component thermodynamic properties. The scripts connect to an SQLite database containing parameter sets and experimental data, and allow users to calculate average absolute deviations (AADs) for saturation and derivative properties.

The main scripts are:

SaturationAAD.jl – Computes deviations for saturation properties.

DerivativeAAD.jl – Computes deviations for derivative properties (e.g., heat capacities, speed of sound).

Requirements

The code is written in Julia and requires the following libraries:

using Clapeyron, PyCall
using SQLite
using DataFrames
using Statistics
using XLSX
import PyPlot; const plt = PyPlot

Database Setup

You will need to specify the path to the SQLite database and the output file for saving results. This can be done by editing the following lines in the scripts:

db_path = raw"your_database_directory_here"   # Path to the SQLite database
file_path = "AAD_results.xlsx"                # Path for saving AAD results
db = SQLite.DB(db_path)


By default, the scripts assume the database is located in the same directory.

Users can change db_path and file_path to point to their own locations.

Running Queries

You can adjust SQL queries to extract specific information (e.g., for certain compounds, temperatures, or pressures).

Example query to extract all records from a given table:

qs_sat = "SELECT * FROM '$TableName'"


You can modify this query to filter specific features, temperature ranges, or pressure conditions.

Output

The scripts calculate AAD values and save results into an Excel file specified by file_path. Plots of selected properties are generated using PyPlot.

Notes

Parameter sets included are taken from the published literature.

The database is provided as a reference to ensure reproducibility.

Users are encouraged to adapt the queries for their own analysis needs.

The units of properties include the database are.
Density    	kg/m³
KT	        10¹⁰·Pa⁻¹
Alpha	      10³·K⁻¹
Cp	        J/(mol·K)
Cv	        J/(mol·K)
Speed      	m/s
Miu	        10⁶·K/Pa
