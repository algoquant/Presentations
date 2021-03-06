##############################
# This is a shiny app for simulating a contrarian strategy 
# using the Hampel filter  over returns.
# 
# Just press the "Run App" button on upper right of this panel.
##############################

## Below is the setup code that runs once when the shiny app is started

# Load R packages
library(HighFreq)
library(shiny)
library(dygraphs)

# Model and data setup

## VTI ETF daily bars
# sym_bol <- "VTI"
# clos_e <- log(Cl(rutils::etf_env$VTI))

## SPY ETF minute bars - works really well !!!
# sym_bol <- "SPY"
# clos_e <- log(Cl(HighFreq::SPY["2011"])["T09:31:00/T15:59:00"])

## Load QM futures 5-second bars
# sym_bol <- "ES"  # S&P500 Emini futures
sym_bol <- "QM"  # oil
load(file=paste0("C:/Develop/data/ib_data/", sym_bol, "_ohlc.RData"))
n_rows <- NROW(oh_lc)
clos_e <- log(Cl(oh_lc))
# Or random prices
# clos_e <- xts(cumsum(rnorm(NROW(oh_lc))), index(oh_lc))

## Load combined futures data
# com_bo <- HighFreq::SPY
# load(file="C:/Develop/data/combined.RData")
# sym_bol <- "UX1"
# symbol_s <- unique(rutils::get_name(colnames(com_bo)))
# clos_e <- log(na.omit(com_bo[, "UX1.Close"]))
# TU1: look_back=14, thresh_old=2.0, lagg=1
# TU1: look_back=30, thresh_old=9.2, lagg=1


## Load VX futures daily bars
# sym_bol <- "VX"
# load(file="C:/Develop/data/vix_data/vix_cboe.RData")
# clos_e <- log(Cl(vix_env$chain_ed))

re_turns <- rutils::diff_it(clos_e)

cap_tion <- paste("Contrarian Strategy for", sym_bol, "Using the Hampel Filter Over Returns")

## End setup code


## Create elements of the user interface
inter_face <- shiny::fluidPage(
  titlePanel(cap_tion),
  
  fluidRow(
    # The Shiny App is recalculated when the actionButton is clicked and the re_calculate variable is updated
    column(width=12,
           h4("Click the button 'Recalculate the Model' to Recalculate the Shiny App."),
           actionButton("re_calculate", "Recalculate the Model"))
  ),  # end fluidRow
  
  # Create single row with two slider inputs
  fluidRow(
    # Input end points interval
    # column(width=2, selectInput("inter_val", label="End points Interval",
    #                             choices=c("days", "weeks", "months", "years"), selected="days")),
    # Input look-back interval
    column(width=2, sliderInput("look_back", label="Lookback", min=3, max=30, value=9, step=1)),
    # Input lag trade parameter
    column(width=2, sliderInput("lagg", label="lagg", min=1, max=5, value=2, step=1)),
    # Input threshold interval
    column(width=2, sliderInput("thresh_old", label="threshold", min=1.0, max=10.0, value=1.8, step=0.2))
    # Input the weight decay parameter
    # column(width=2, sliderInput("lamb_da", label="Weight decay:",
    #                             min=0.01, max=0.99, value=0.1, step=0.05)),
    # Input model weights type
    # column(width=2, selectInput("typ_e", label="Portfolio weights type",
    #                             choices=c("max_sharpe", "min_var", "min_varpca", "rank"), selected="rank")),
    # Input number of eigenvalues for regularized matrix inverse
    # column(width=2, sliderInput("max_eigen", "Number of eigenvalues", min=2, max=20, value=15, step=1)),
    # Input the shrinkage intensity
    # column(width=2, sliderInput("al_pha", label="Shrinkage intensity",
    #                             min=0.01, max=0.99, value=0.1, step=0.05)),
    # Input the percentile
    # column(width=2, sliderInput("percen_tile", label="percentile:", min=0.01, max=0.45, value=0.1, step=0.01)),
    # Input the strategy coefficient: co_eff=1 for momentum, and co_eff=-1 for contrarian
    # column(width=2, selectInput("co_eff", "Coefficient:", choices=c(-1, 1), selected=(-1))),
    # Input the bid-offer spread
    # column(width=2, numericInput("bid_offer", label="bid-offer:", value=0.001, step=0.001))
  ),  # end fluidRow
  
  # Create output plot panel
  mainPanel(dygraphs::dygraphOutput("dy_graph"), width=12)
  
)  # end fluidPage interface


## Define the server code
ser_ver <- function(input, output) {
  
  # Recalculate the data and rerun the model
  da_ta <- reactive({
    # Get model parameters from input argument
    look_back <- isolate(input$look_back)
    lagg <- isolate(input$lagg)
    # max_eigen <- isolate(input$max_eigen)
    thresh_old <- isolate(input$thresh_old)
    # look_lag <- isolate(input$look_lag
    # lamb_da <- isolate(input$lamb_da)
    # typ_e <- isolate(input$typ_e)
    # al_pha <- isolate(input$al_pha)
    # percen_tile <- isolate(input$percen_tile)
    # co_eff <- as.numeric(isolate(input$co_eff))
    # bid_offer <- isolate(input$bid_offer)
    # Model is recalculated when the re_calculate variable is updated
    input$re_calculate

    
    # look_back <- 11
    # half_window <- look_back %/% 2
    
    # Rerun the model
    medi_an <- TTR::runMedian(re_turns, n=look_back)
    medi_an[1:look_back, ] <- 1
    ma_d <- TTR::runMAD(re_turns, n=look_back)
    ma_d[1:look_back, ] <- 1
    z_scores <- ifelse(ma_d != 0, (re_turns-medi_an)/ma_d, 0)
    z_scores[1:look_back, ] <- 0
    # mad_zscores <- TTR::runMAD(z_scores, n=look_back)
    # mad_zscores[1:look_back, ] <- 0
    mad_zscores <- 1
    
    # Calculate position_s and pnls from z-scores and ran_ge
    position_s <- rep(NA_integer_, n_rows)
    position_s[1] <- 0
    # thresh_old <- 3*mad(z_scores)
    # position_s <- ifelse(z_scores > thresh_old, -1, position_s)
    # position_s <- ifelse(z_scores < (-thresh_old), 1, position_s)
    position_s <- ifelse(z_scores > thresh_old*mad_zscores, -1, position_s)
    position_s <- ifelse(z_scores < (-thresh_old*mad_zscores), 1, position_s)
    position_s <- zoo::na.locf(position_s, na.rm=FALSE)
    position_s <- rutils::lag_it(position_s, lagg=lagg)
    
    # re_turns <- rutils::diff_it(clos_e)
    pnl_s <- cumsum(position_s*re_turns)
    pnl_s <- cbind(pnl_s, cumsum(re_turns))
    colnames(pnl_s) <- c("Strategy", "Index")
    # pnl_s[rutils::calc_endpoints(pnl_s, inter_val="minutes")]
    # pnl_s[rutils::calc_endpoints(pnl_s, inter_val="hours")]
    pnl_s
  })  # end reactive code
  
  # Return to the output argument a dygraph plot with two y-axes
  output$dy_graph <- dygraphs::renderDygraph({
    col_names <- colnames(da_ta())
    dygraphs::dygraph(da_ta(), main=cap_tion) %>%
      dyAxis("y", label=col_names[1], independentTicks=TRUE) %>%
      dyAxis("y2", label=col_names[2], independentTicks=TRUE) %>%
      dySeries(name=col_names[1], axis="y", label=col_names[1], strokeWidth=1, col="red") %>%
      dySeries(name=col_names[2], axis="y2", label=col_names[2], strokeWidth=1, col="blue")
  })  # end output plot
  
}  # end server code

## Return a Shiny app object
shiny::shinyApp(ui=inter_face, server=ser_ver)
