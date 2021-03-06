// hierarchical habitat-detection model for elevational and habitat associations

functions{
    real partial_sum(int[,] det_slice, 
                     int start, int end, 
                     vector b0,
                     vector b1,
                     vector b2,
                     vector b3,
                     vector b3_upr, 
                     real b4,
                     real b5,
                     vector mid0,
                     vector site_sp,
                     vector cl_sp,
                     vector obs_sp,
                     vector d0, 
                     vector d1,
                     vector d2,
                     int[] n_visit,
                     row_vector[] time,
                     int[] id_sp, 
                     int[] id_site_sp,
                     int[] id_cl_sp,
                     int[] id_obs_sp,
                     row_vector[] id_obs_JS,
                     row_vector[] id_obs_DE,
                     int[] Q, 
                     vector range_pos,
                     vector habitat, 
                     vector ele_midpoint, 
                     vector ele_midpoint_x_habitat) {
                         
        // indexing vars
        int len = end - start + 1;
        int r0 = start - 1;

        // calculated quantities
        vector[len] lp;
        real logit_psi;
        row_vector[4] logit_theta;
        real dist;
        real dist_upr;
        
        for (r in 1:len) {
            // calculate distance from estimated centre of occupancy
            dist = (range_pos[r0+r] - mid0[id_sp[r0+r]])^2;

            // calculate dist_upr (i.e. dist * dummy variable on range half)
            if(range_pos[r0+r] < mid0[id_sp[r0+r]]) {
                dist_upr = 0;
            } else {
                dist_upr = dist;
            }
            // occupancy
            logit_psi = site_sp[id_site_sp[r0+r]] + cl_sp[id_cl_sp[r0+r]] +
                b0[id_sp[r0+r]] +
                b1[id_sp[r0+r]]*habitat[r0+r] +
                b2[id_sp[r0+r]]*dist +
                b3[id_sp[r0+r]]*habitat[r0+r]*dist +
                b3_upr[id_sp[r0+r]]*habitat[r0+r]*dist_upr +
                b4*ele_midpoint[r0+r] +
                b5 * ele_midpoint_x_habitat[r0+r]; //elevationally-varying habitat effect

            // detection
            logit_theta[1:n_visit[r0+r]] = obs_sp[id_obs_sp[r0+r]] +
                d0[id_sp[r0+r]] + 
                d1[id_sp[r0+r]]*time[r0+r, 1:n_visit[r0+r]] + 
                d2[1]*id_obs_JS[r0+r, 1:n_visit[r0+r]] + 
                d2[2]*id_obs_DE[r0+r, 1:n_visit[r0+r]];
            
            // likelihood
            if (Q[r0 + r] == 1) 
                lp[r] = log_inv_logit(logit_psi) +
                    bernoulli_logit_lpmf(det_slice[r, 1:n_visit[r0+r]] | logit_theta[1:n_visit[r0+r]]);
            else lp[r] = log_sum_exp(
                log_inv_logit(logit_psi) + sum(log1m_inv_logit(logit_theta[1:n_visit[r0+r]])),
                log1m_inv_logit(logit_psi));
        } 
        return sum(lp);
    }
}
data {
    // dimensions
    int<lower=1> n_species; //number of species
    int<lower=1> n_cluster_species; //number of species:cluster combinations
    int<lower=1> n_site_species; // number of species:cluster combinations
    int<lower=1> n_obs_species; // number of site:observer combinations
    int<lower=1> n_points; //number of species
    //int<lower=1> n_ele_midpoint_f; // number of levels of ele_midpoint index var
    int<lower=1> n_tot; // nrows in df
    int<lower=1> n_visit[n_tot]; //variable number of visits
    // note: 4 is the maximum number of visits (visit-specific matrices all have 
    // this maximum dimension)
    
    // indexing variables
    int<lower=1> id_sp[n_tot]; // species ID
    int<lower=1> id_cl_sp[n_tot]; // cluster:species ID
    int<lower=1> id_site_sp[n_tot]; // site:species ID
    int<lower=1> id_obs_sp[n_tot]; // observer:species ID
    row_vector[4] id_obs_JS[n_tot]; // JS visits
    row_vector[4]  id_obs_DE[n_tot]; // DE visits
    
    // data & covariates
    row_vector[4] time[n_tot]; // stdised time of day (-99 for dropped visits)
    int det_data[n_tot, 4]; // detection history (-99 for dropped visits)
    int<lower=0, upper=1> Q[n_tot]; // detection/non-detection across visits
    vector[n_tot] range_pos; // scaled elevations [-1, 1] (i.e. range position)
    vector[n_tot] habitat; // stdised habitat
    vector[n_tot] ele_midpoint; // species range midpoint: stdised elevation
    int<lower=1> grainsize;
} 
transformed data{
    vector[n_tot] ele_midpoint_x_habitat = ele_midpoint .* habitat;
}
parameters {
    // occupancy-term ranef mus
    real mu_b0;
    real mu_b1;
    real mu_b2;
    real mu_b3;
    real mu_b3_upr;
    real mu_mid0;
    
    // occupancy-term fixefs
    real b4;
    real b5; 
    
    // occupancy-term ranef sigmas
    real<lower=0> sigma_b0;
    vector[n_species] b0_z;
    
    real<lower=0> sigma_b1;
    vector[n_species] b1_z;
    
    real<lower=0> sigma_b2;
    vector[n_species] b2_z;
   
    real<lower=0> sigma_b3;
    vector[n_species] b3_z;
    
    real<lower=0> sigma_b3_upr;
    vector[n_species] b3_upr_z;
    
    real<lower=0> sigma_mid0;
    vector[n_species] mid0_z;
    
    // 0-centred occupancy ranef sigmas
    real<lower=0> sigma_cl_sp;
    vector[n_cluster_species] cl_sp_z;
    
    real<lower=0> sigma_site_sp;
    vector[n_site_species] site_sp_z;
    
    // detection-term ranef mus
    real mu_d0;
    real mu_d1;
    
    // 2-level observer fixef (JS and DE)
    vector[2] d2;
    
    // detection-term ranef sigmas
    real<lower=0> sigma_d0;
    vector[n_species] d0_z;
    
    real<lower=0> sigma_d1;
    vector[n_species] d1_z;
    
    // 0-centered detection ranef sigmas
    real<lower=0> sigma_obs_sp;
    vector[n_obs_species] obs_sp_z;
}
transformed parameters {
    // occupancy
    vector[n_species] b0 = mu_b0 + b0_z * sigma_b0;
    vector[n_species] b1 = mu_b1 + b1_z * sigma_b1;
    vector[n_species] b2 = mu_b2 + b2_z * sigma_b2;
    vector[n_species] b3 = mu_b3 + b3_z * sigma_b3;
    vector[n_species] b3_upr = mu_b3_upr + b3_upr_z * sigma_b3_upr;
    
    vector[n_species] mid0 = mu_mid0 + mid0_z * sigma_mid0;
    vector[n_cluster_species] cl_sp = cl_sp_z * sigma_cl_sp;
    vector[n_site_species] site_sp = site_sp_z * sigma_site_sp;
   
    // detection
    vector[n_species] d0 = mu_d0 + d0_z * sigma_d0;
    vector[n_species] d1 = mu_d1 + d1_z * sigma_d1;
    
    vector[n_obs_species] obs_sp = obs_sp_z * sigma_obs_sp;
}
model {
    // Likelihood
    target += reduce_sum_static(partial_sum, det_data, grainsize, 
                                b0, b1, b2, b3, b3_upr, b4, b5, mid0,
                                site_sp, cl_sp, obs_sp,
                                d0, d1, d2,
                                n_visit, time,
                                id_sp, id_site_sp, id_cl_sp, id_obs_sp,
                                id_obs_JS, id_obs_DE,
                                Q, range_pos, habitat, ele_midpoint, ele_midpoint_x_habitat);
    
    // Ranef hyper-priors 
    // mus 
    mu_mid0 ~ normal(0, 1);
    mu_b0 ~ student_t(7.76, 0, 1.57);
    mu_b1 ~ normal(0, 3);
    mu_b2 ~ normal(-3, 4);
    mu_b3 ~ normal(0, 3);
    mu_b3_upr ~ normal(0, 3);
    
    mu_d0 ~ student_t(7.76, 0, 1.57);
    mu_d1 ~ normal(0, 3); 
    
    // sigmas
    sigma_mid0 ~ normal(0, 2);
    sigma_b0 ~ normal(0, 2);
    sigma_b1 ~ normal(0, 2);
    sigma_b2 ~ normal(0, 2);
    sigma_b3 ~ normal(0, 2);
    sigma_b3_upr ~ normal(0, 2);
    
    sigma_site_sp ~ normal(0, 2);
    sigma_cl_sp ~ normal(0, 2);
    sigma_obs_sp ~ normal(0, 2);
    
    sigma_d0 ~ normal(0, 2);
    sigma_d1 ~ normal(0, 2);
    
    // standard normals
    mid0_z ~ normal(0, 1);
    b0_z ~ normal(0, 1);
    b1_z ~ normal(0, 1);
    b2_z ~ normal(0, 1);
    b3_z ~ normal(0, 1);
    b3_upr_z ~ normal(0, 1);
    
    site_sp_z ~ normal(0, 1);
    cl_sp_z ~ normal(0, 1);
    obs_sp_z ~ normal(0, 1);
    
    d0_z ~ normal(0, 1);
    d1_z ~ normal(0, 1);
    
    // Fixefs
    b4 ~ normal(0, 2);
    b5 ~ normal(0, 2);
    d2 ~ student_t(7.76, 0, 1.57);
    
}
generated quantities {
    // store lps
    vector[n_tot] log_lik;
    real logit_psi;
    row_vector[4] logit_theta;
    real dist;
    real dist_upr;
    
     for (r in 1:n_tot) {
            // calculate distance from estimated centre of occupancy
            dist = (range_pos[r] - mid0[id_sp[r]])^2;

            // calculate dist_upr (i.e. dist * dummy variable on range half)
            if(range_pos[r] < mid0[id_sp[r]]) {
                dist_upr = 0;
            } else {
                dist_upr = dist;
            }
            // occupancy
            logit_psi = site_sp[id_site_sp[r]] + cl_sp[id_cl_sp[r]] +
                b0[id_sp[r]] +
                b1[id_sp[r]]*habitat[r] +
                b2[id_sp[r]]*dist +
                b3[id_sp[r]]*habitat[r]*dist +
                b3_upr[id_sp[r]]*habitat[r]*dist_upr +
                b4*ele_midpoint[r] +
                b5 * ele_midpoint_x_habitat[r]; //elevationally-varying habitat effect

            // detection
            logit_theta[1:n_visit[r]] = obs_sp[id_obs_sp[r]] +
                d0[id_sp[r]] + 
                d1[id_sp[r]]*time[r, 1:n_visit[r]] + 
                d2[1]*id_obs_JS[r, 1:n_visit[r]] + 
                d2[2]*id_obs_DE[r, 1:n_visit[r]];
            
            // likelihood
            if (Q[r] == 1) 
                log_lik[r] = log_inv_logit(logit_psi) +
                    bernoulli_logit_lpmf(det_data[r, 1:n_visit[r]] | logit_theta[1:n_visit[r]]);
            else log_lik[r] = log_sum_exp(
                log_inv_logit(logit_psi) + sum(log1m_inv_logit(logit_theta[1:n_visit[r]])),
                log1m_inv_logit(logit_psi));
        } 
}
