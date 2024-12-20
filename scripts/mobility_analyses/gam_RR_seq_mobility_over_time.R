## This script implements GAM to evaluate the percentage of the variance in the genetic data 
## explained by genetic data. It also identifies outliers in the relationship between genetic
## and mobility from the GAM. The analysis is stratified by epidemic waves.

library(mgcv)
library(tidyverse)
library(vegan)
library(broom)
library(ggrepel)
library(ggpubr)
source('../utils_comp_RR.R')

## Load relative risk of observing identical sequences between regions
vec_periods <- 1:4
df_RR_regions_by_period <- Reduce('bind_rows', lapply(vec_periods, FUN = function(i_period){
  read_csv(paste0('../../results/RR_region_by_period/df_RR_region_0_mut_away_period_', i_period, '.csv')) %>% 
    rename(RR_seq = RR) %>% ungroup() %>% 
    mutate(i_period = i_period)
}))
df_uncertainty_RR_regions_by_period <- Reduce('bind_rows', lapply(vec_periods, FUN = function(i_period){
  readRDS(paste0('../../results/RR_region_by_period/df_RR_uncertainty_region_0_mut_away_period_', i_period, '.rds')) %>% 
    ungroup()
}))

## Load relative risk of movements between regions
df_RR_mobility_mobile_phone_region_by_period <- Reduce('bind_rows', lapply(vec_periods, FUN = function(i_period){
  readRDS(paste0('../../results/RR_mobility/RR_mobile_phone_region_WA_period_', i_period, '.rds')) %>% 
    rename(RR_mobile_phone = RR) %>% ungroup() %>% 
    mutate(i_period = i_period)
}))

df_RR_for_comparison_regions <- df_RR_regions_by_period %>% select(group_1, group_2, RR_seq, i_period, n_pairs) %>% 
  left_join(df_uncertainty_RR_regions_by_period) %>% 
  left_join(df_RR_mobility_mobile_phone_region_by_period %>% select(region_1, region_2, RR_mobile_phone, i_period),
            by = c('group_1' = 'region_1', 'group_2' = 'region_2', 'i_period')) %>% 
  mutate(log_RR_seq = log(RR_seq), log_RR_mobile_phone = log(RR_mobile_phone)) %>% 
  filter(group_1 >= group_2)

## Load adjacency between counties
df_adj_county <- readRDS('../../data/maps/df_adj_county.rds') %>% 
  as_tibble() %>% 
  rename(group_1 = county_1, group_2 = county_2)

## Run GAM between the RR of movement from mobile phone mobility data
## and the RR of observing identical sequences between regions
## for each of the 4 time periods
gam_seq_mobile_phone_regions_by_period <- lapply(vec_periods, FUN = function(curr_i_period){
  run_gam(df_with_RR_for_gam = df_RR_for_comparison_regions %>% filter(RR_mobile_phone > 0., RR_seq > 0., i_period == curr_i_period),
          predictor_name = 'log_RR_mobile_phone', response_name = 'log_RR_seq', 
          k_gam = 5)
})

sapply(gam_seq_mobile_phone_regions_by_period, FUN = function(curr_gam){
  summary(curr_gam$mod)$r.sq
})
sapply(gam_seq_mobile_phone_regions_by_period, FUN = function(curr_gam){
  summary(curr_gam$mod)$s.pv
})
lapply(gam_seq_mobile_phone_regions_by_period, FUN = function(curr_gam){
  curr_gam$df_outliers_fit
})


## Make plot with fit for each of the time period
list_plots_fits_gam <- lapply(vec_periods, FUN = function(i_period){
  curr_gam <- gam_seq_mobile_phone_regions_by_period[[i_period]]
  
  plot_fit_gam_regions(res_gam = curr_gam, 
                       transform_func_response = 'exp', transform_func_predictor = 'exp',
                       name_x_axis = expression(RR['mobility']),
                       breaks_x_axis = c(1e-3, 1e-2, 1e-1, 1., 1e1, 1e2, 1e3, 1e4),
                       labels_x_axis = c(expression(10^{-3}), expression(10^{-2}), expression(10^{-1}),
                                         expression(10^{0}), expression(10^{1}), expression(10^{2}), expression(10^{3}),
                                         expression(10^{4})),
                       trans_x_axis_plot = 'log',
                       name_y_axis = expression(RR['identical sequences']),
                       breaks_y_axis = c(1, 2, 5),
                       labels_y_axis =c(1, 2, 5),
                       trans_y_axis_plot = 'log') + 
    ggtitle(paste0('Wave ', 3 + i_period)) +
    theme(plot.margin = unit(c(0.2, 0.2, 0.2, 0.2), 
                             "inches")) +
    annotate(x = 0, y = Inf, 
             geom = 'text', 
             label = paste0('R^{2}~`=`~', round(summary(curr_gam$mod)$r.sq, 2)),
             hjust = -.5, vjust = 1., parse = T)
})

## Make a panel with the 4 plots
panel_gam_mobile_phone_over_time <- ggarrange(plotlist =list_plots_fits_gam, nrow = 2, ncol = 2, 
                                              labels = 'AUTO') 

# pdf('../plots/figure_mobility/panel_gam_safegraph_counties_over_time_with_R2.pdf',
#     height = 8, width = 8)
plot(panel_gam_mobile_phone_over_time)
#dev.off()
