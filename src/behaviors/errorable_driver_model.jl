export 
    ErrorableDriverModel,
    get_name,
    action_context
    set_desired_speed!,
    observe!,
    rand,
    pdf,
    logpdf,
    srand

import AutomotiveDrivingModels: 
    LongitudinalDriverModel,
    get_name,
    set_desired_speed!,
    track_longitudinal!,
    observe!

"""
Description:
    - sample from a bernoulli distribution with success probability p
"""
bernoulli_sample(rng::MersenneTwister, p::Float64) = rand(rng) < p

"""
Description:
    - Basic errorable driver model. Suffers from inattentiveness.
"""
type ErrorableDriverModel <: DriverModel{LatLonAccel, ActionContext}
    driver::DriverModel
    is_attentive::Bool
    p_a_to_i::Float64 # p(true) = p(attentive -> inattentive)
    p_i_to_a::Float64 # p(true) = p(inattentive -> attentive)
    rng::MersenneTwister # for reproducing attentiveness changes
    function ErrorableDriverModel(driver::DriverModel; 
            p_a_to_i::Float64 = 0.01, 
            p_i_to_a::Float64 = 0.3,
            rng::MersenneTwister = MersenneTwister(1))
        return new(driver, true, p_a_to_i, p_i_to_a, rng)
    end
end

get_name(::ErrorableDriverModel) = "ErrorableDriverModel"
action_context(model::ErrorableDriverModel) = action_context(model.driver)
set_desired_speed!(model::ErrorableDriverModel, v_des::Float64) = set_desired_speed!(
    model.driver, v_des)
get_driver(model::ErrorableDriverModel) = get_driver(model.driver)
Base.srand(model::ErrorableDriverModel, seed::Int) = srand(model.rng, seed)
function can_become_inattentive(model::ErrorableDriverModel)
    base_driver = get_driver(model)
    if :mlane in fieldnames(base_driver)
        return base_driver.mlane.dir == DIR_MIDDLE
    end
    return true
end
function observe!(model::ErrorableDriverModel, scene::Scene, roadway::Roadway, 
        egoid::Int)

    # only observe if attentive
    if model.is_attentive
        observe!(model.driver, scene, roadway, egoid)
    end

    if (model.is_attentive 
            && bernoulli_sample(model.rng, model.p_a_to_i)
            && can_become_inattentive(model))
        model.is_attentive = false
    elseif (!model.is_attentive 
            && bernoulli_sample(model.rng, model.p_i_to_a))
        model.is_attentive = true
    end 
    # it's possible to reach this point without having changed the state

    return model
end
Base.rand(model::ErrorableDriverModel) = rand(model.driver)
Distributions.pdf(model::ErrorableDriverModel, a::LatLonAccel) = pdf(
    model.driver, a)
Distributions.logpdf(model::ErrorableDriverModel, a::LatLonAccel) = logpdf(
    model.driver, a)