module TiingoAPI

using HTTP
using JSON3
using DataFrames
using Dates
using DotEnv

export fetch_historical_data, load_api_key

"""
    load_api_key()

Load Tiingo API key from environment variables.
"""
function load_api_key()
    env_path = joinpath(dirname(@__DIR__), ".env")
    if isfile(env_path)
        # Load environment variables from .env file
        dotenv = DotEnv.parse(read(env_path, String))
        for (key, value) in dotenv
            ENV[key] = value
        end
    end
    api_key = get(ENV, "TIINGO_API_KEY", nothing)
    if isnothing(api_key) || api_key == "your_tiingo_api_key_here"
        error("Please set TIINGO_API_KEY in your .env file")
    end
    return api_key
end

"""
    fetch_historical_data(ticker::String; years_back::Int=3, end_date::Date=today(), api_key::String=load_api_key())

Fetch historical daily price data from Tiingo for a given ticker.
Returns a DataFrame with dates and prices.
end_date: The last date to fetch data (for historical analysis, use pricing date)
"""
function fetch_historical_data(ticker::String; years_back::Int=3, end_date::Date=today(), api_key::String=load_api_key())
    # Calculate date range
    start_date = end_date - Year(years_back)

    # Format dates for Tiingo API (YYYY-MM-DD)
    start_str = Dates.format(start_date, "yyyy-mm-dd")
    end_str = Dates.format(end_date, "yyyy-mm-dd")

    # Build API URL
    base_url = "https://api.tiingo.com/tiingo/daily"
    url = "$base_url/$ticker/prices?startDate=$start_str&endDate=$end_str&token=$api_key"

    println("Fetching data for $ticker from $start_str to $end_str...")

    # Make API request
    try
        response = HTTP.get(url, headers=["Content-Type" => "application/json"])

        if response.status != 200
            error("API request failed with status: $(response.status)")
        end

        # Parse JSON response
        data = JSON3.read(String(response.body))

        # Convert to DataFrame
        if isempty(data)
            error("No data returned for ticker: $ticker")
        end

        # Extract dates and adjusted close prices
        dates = Date[]
        prices = Float64[]

        for item in data
            push!(dates, Date(item.date[1:10]))  # Extract date part from datetime string
            push!(prices, Float64(item.adjClose))
        end

        df = DataFrame(Date=dates, Close=prices)

        # Sort by date (should already be sorted, but ensuring)
        sort!(df, :Date)

        println("  Retrieved $(nrow(df)) data points for $ticker")

        return df

    catch e
        if isa(e, HTTP.ExceptionRequest.StatusError)
            if e.status == 404
                error("Ticker $ticker not found in Tiingo database")
            elseif e.status == 401
                error("Invalid API key. Please check your TIINGO_API_KEY")
            else
                error("HTTP error $(e.status): $(e)")
            end
        else
            rethrow(e)
        end
    end
end

"""
    calculate_log_returns(prices::Vector{Float64})

Calculate log returns from a price series.
"""
function calculate_log_returns(prices::Vector{Float64})
    return diff(log.(prices))
end

"""
    fetch_and_prepare_returns(ticker::String; years_back::Int=3, end_date::Date=today(), api_key::String=load_api_key())

Fetch historical data and return log returns directly.
"""
function fetch_and_prepare_returns(ticker::String; years_back::Int=3, end_date::Date=today(), api_key::String=load_api_key())
    df = fetch_historical_data(ticker; years_back=years_back, end_date=end_date, api_key=api_key)
    returns = calculate_log_returns(df.Close)
    return returns, df
end

"""
    get_latest_price(ticker::String; target_date::Date=today(), api_key::String=load_api_key())

Get the closing price for a ticker on or near a specific date.
"""
function get_latest_price(ticker::String; target_date::Date=today(), api_key::String=load_api_key())
    # Fetch data around target date to ensure we get the closest trading day
    start_date = target_date - Day(10)
    end_date = target_date + Day(5)  # Allow a few days after in case target_date is a weekend

    start_str = Dates.format(start_date, "yyyy-mm-dd")
    end_str = Dates.format(end_date, "yyyy-mm-dd")

    base_url = "https://api.tiingo.com/tiingo/daily"
    url = "$base_url/$ticker/prices?startDate=$start_str&endDate=$end_str&token=$api_key"

    try
        response = HTTP.get(url, headers=["Content-Type" => "application/json"])

        if response.status != 200
            error("API request failed with status: $(response.status)")
        end

        data = JSON3.read(String(response.body))

        if isempty(data)
            error("No recent data for ticker: $ticker")
        end

        # Find the price closest to target date (but not after if we're doing historical pricing)
        best_date = Date("1900-01-01")
        best_price = 0.0

        for item in data
            item_date = Date(item.date[1:10])
            if item_date <= target_date && item_date > best_date
                best_date = item_date
                best_price = Float64(item.adjClose)
            end
        end

        if best_date == Date("1900-01-01")
            error("No price data found on or before $target_date for ticker: $ticker")
        end

        return best_price

    catch e
        if isa(e, HTTP.ExceptionRequest.StatusError)
            if e.status == 404
                error("Ticker $ticker not found")
            elseif e.status == 401
                error("Invalid API key")
            else
                rethrow(e)
            end
        else
            rethrow(e)
        end
    end
end

end # module