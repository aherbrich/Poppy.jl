## Overview

Poppy is a lightweight chess engine written in Julia as part of a Bachelor's thesis project. Its primary focus is to provide a platform for easy experimentation and research in chess engine optimization. The engine is designed to be straightforward to understand while offering decent performance for analysis and testing purposes.

### How to Use

1. Clone the repository
2. `cd` into the repository
3. Start a Julia REPL with project environment activated
    ```bash
    julia --project=.
    ```
    or, alternatively, you can start Julia and activate the project environment from within the Pkg mode in the REPL (press `]` in the REPL)
    ```julia
    julia> ]
    (Poppy) pkg> activate .
    ```
4. Install the dependencies (listed in the `Project.toml` file), by entering the Pkg mode in the REPL and running
    ```julia
    julia> ]
    (Poppy) pkg> instantiate
    ```
    alternatively, you might need to run `resolve` or `update` instead of `instantiate`.
5. To use any library function, call it with the following syntax:
    ```julia
    Poppy.SubmoduleName.function_name()
    ```

### How to Bachelor Thesis
Specifically, to parse training files, train a model and then evaluate it (as in the bachelor thesis), follow these steps:

1. Download the training data in `.pgn` format, for example from [Lichess](https://database.lichess.org/)
2. Filter by Elo and clean the data using
    ```julia
      Poppy.Parser.filter_elo("path/to/input.pgn", min_elo, folder="path/to/output")

      Poppy.Parser.clean_pgn("path/to/input.pgn", folder="path/to/output")
    ```
3. Now train and test the model, using the following command *(warning: this produces many relatively large prediction files)*
    ```julia
      Poppy.Train.train_and_test_models("path/to/training_data", max_test_set_size=xyz)
    ```
    The prediction files are named after the following pattern: `(model-type)_(feature-set/move-representation)_trained_on_(nr-of-games-trained-on)_id_(unique-id).bin`
4. Finally, analyze the prediction data with functions provided in the file `src/analysis/plotting.jl`, for example
    ```julia
      Poppy.PatternLearning.plot_overall_accuracy(unique_training_id, number_of_games_trained_on)
    ```
    Note that with the `unique_training_id` and `number_of_games_trained_on` you can specify which prediction data of what model (and training batch) to analyze. Also note that in the current implementation, the folder of the prediction data is hard-coded in the plotting functions, so you might need to adjust that (potenially you may have to run `include("src/Poppy.jl")` again).
5. The functions with which the figures in the bachelor thesis were prodcued are listed in the following table. The exact numbers referenced in the text were produced as a byproduct (console log) of the respective functions. More generally, all figures (and console logs) can be generated by call of the function `plot_all(-,-)`. Note that the notation `(-,-)` indicates that the function takes two arguments (unique_training_id, number_of_games_trained_on) as described above. 

    Figure | Function
    --- | ---
    5.1 | `plot_overall_accuracy(-,-)`
    5.2 | `plot_top_k_accuracy(-,-)`
    5.3 | `plot_top_k_accuracy(-,-)`
    5.4 | `plot_accuracy_over_time(-)`
    5.5 | `plot_per_ply(-,-)`
    5.6 | `plot_per_ply(-,-)`
    5.7 | `plot_per_move_type(-,-)`
    5.8 | `visualize_piece_sq(-,-,feature_set_name="v1")`
    5.9 | `visualize_move_type(-,-,feature_set_name="v2")`

    Notable exceptions are Figures 3.7a and 3.7b (concerning approximation in the greater-than factor), which can be generated by calling the following functions:
    ```julia
    Poppy.PatternLearning.plot_greater_than_good_approximation()
    Poppy.PatternLearning.plot_greater_than_poor_approximation()
    ```

6. The functions with which the tables in the bachelor thesis were produced are listed in the following table.

    Table | Function
    --- | ---
    5.1 | console log of `plot_per_move_type(-,-)`
    5.2 | `nr_of_features(-,-)`
    5.3 | `nr_of_features(-,-)`


   


### References & Literature

The testing suite to check for correct move generation, was adapted from the [Blunder](https://github.com/deanmchris/blunder) chess engine, specifically from the file [perft_suite.epd](https://github.com/deanmchris/blunder/blob/main/perft_suite/perft_suite.epd). The initial logic of the **legal** move generator was inspired by the [Surge - A fast bitboard-based legal chess move generator](https://github.com/nkarve/surge), though the final implementation differs quite substantially.