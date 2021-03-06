##############################
# This is a shiny app for backtesting a minimum variance 
# rolling portfolio optimization strategy, which produces 
# an interactive dygraphs plot.
# 
# This is an old student version that compiles Rcpp code 
# from package HighFreq.
# 
# Just press the "Run App" button on upper right of this panel.
##############################

## Below is the setup code that runs once when the shiny app is started

# load packages
library(shiny)
library(dygraphs)
library(HighFreq)
# Compile Rcpp code from package HighFreq
Rcpp::sourceCpp(file="C:/Develop/lecture_slides/assignments/rcpp_strat.cpp")
# Model and data setup
load("C:/Develop/lecture_slides/data/sp500_prices.RData")
re_turns <- returns_100
n_weights <- NCOL(re_turns)
risk_free <- 0.03/260
ex_cess <- (re_turns - risk_free)
# calculate returns on equal weight portfolio
in_dex <- xts(cumsum(re_turns %*% rep(1/sqrt(n_weights), n_weights)), index(re_turns))


# End setup code


## Create elements of the user interface
inter_face <- shiny::fluidPage(
  titlePanel("Rolling Portfolio Optimization Strategy for S&P500 Sub-portfolio"),
  
  fluidRow(
    # The Shiny App is recalculated when the actionButton is clicked and the re_calculate variable is updated
    column(width=12, 
           h4("Click the button 'Recalculate the Model' to Recalculate the Shiny App."),
           actionButton("re_calculate", "Recalculate the Model"))
  ),  # end fluidRow
  
  # Create single row with two slider inputs
  fluidRow(
    # Input number of eigenvalues for regularized matrix inverse
    column(width=4, numericInput("max_eigen", "Number of eigenvalues:", value=45)),
    # Input end points interval
    column(width=4, selectInput("inter_val", label="End points Interval",
                choices=c("weeks", "months", "years"), selected="months")),
    # Input look-back interval
    column(width=4, sliderInput("look_back", label="Look-back interval:",
                                min=1, max=30, value=12, step=1)),
    # Input end_stub interval
    # column(width=4, sliderInput("end_stub", label="End_stub interval:",
    #                             min=1, max=90, value=30, step=1)),
    # Input the shrinkage intensity
    column(width=4, sliderInput("al_pha", label="Shrinkage intensity:",
                                min=0.01, max=0.99, value=0.8, step=0.05))
  ),  # end fluidRow
  
  # Create output plot panel
  mainPanel(dygraphs::dygraphOutput("dy_graph"), width=12)
)  # end fluidPage interface


## Define the server code
ser_ver <- function(input, output) {

  # Recalculate the data and rerun the model
  da_ta <- reactive({
    # Get model parameters from input argument
    inter_val <- isolate(input$inter_val)
    max_eigen <- isolate(input$max_eigen)
    al_pha <- isolate(input$al_pha)
    look_back <- isolate(input$look_back)
    # end_stub <- input$end_stub
    # Model is recalculated when the re_calculate variable is updated
    input$re_calculate
    
    # Define end points
    end_points <- rutils::calc_endpoints(re_turns, inter_val=inter_val)
    # end_points <- ifelse(end_points<(n_weights+1), n_weights+1, end_points)
    end_points <- end_points[end_points > (n_weights+1)]
    len_gth <- NROW(end_points)
    # Define start_points
    start_points <- c(rep_len(1, look_back-1), end_points[1:(len_gth-look_back+1)])
    # Rerun the model
    pnl_s <- back_test(ex_cess=re_turns, 
                        re_turns=re_turns,
                        start_points=start_points-1,
                        end_points=end_points-1,
                        max_eigen=max_eigen, 
                        al_pha=al_pha)
    pnl_s[which(is.na(pnl_s)), ] <- 0
    # pnl_s <- back_test_r(ex_cess, re_turns, start_points, end_points, al_pha, max_eigen, end_stub)
    # pnl_s <- sd(rutils::diff_it(in_dex))*pnl_s/sd(rutils::diff_it(pnl_s))
    pnl_s <- cumsum(pnl_s)
    pnl_s <- cbind(pnl_s, in_dex)
    colnames(pnl_s) <- c("Strategy", "Index")
    pnl_s[c(1, end_points), ]
  })  # end reactive code
  
  # Return to output argument a dygraph plot with two y-axes
  output$dy_graph <- dygraphs::renderDygraph({
    col_names <- colnames(da_ta())
    dygraphs::dygraph(da_ta(), main="Rolling Portfolio Optimization Strategy") %>%
      dyAxis("y", label=col_names[1], independentTicks=TRUE) %>%
      dyAxis("y2", label=col_names[2], independentTicks=TRUE) %>%
      dySeries(name=col_names[1], axis="y", label=col_names[1], strokeWidth=1, col="red") %>%
      dySeries(name=col_names[2], axis="y2", label=col_names[2], strokeWidth=1, col="blue")
  })  # end output plot
  
}  # end server code

## Return a Shiny app object
shiny::shinyApp(ui=inter_face, server=ser_ver)
