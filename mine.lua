local EXECS_COEF = 0.50
local WEIGHTDIFF_COEF = 0.92
local DIFF_LIMIT = 1.00

local CHANCE_MUTATION_RESET_CONNECTION = 0.25
local WEIGHT_CONNECTION_MUTATION_ADD = 0.80
local CHANCE_MUTATION_WEIGHT = 0.95
local CHANCE_MUTATION_CONNECTION = 0.85
local CHANCE_MUTATION_NEURON = 0.25
local END_FITNESS = 1000000

local NB_NEURON_MAX = 9999
local NB_INDIVIDUAL_POPULATION = 100
local NB_INPUT = 8
local NB_OUTPUT = 8

local NEURONS = {
    INPUT = "input",
    HIDDEN = "hidden",
    OUTPUT = "output",
}

innovationNb = 0
fitnessMax = 0
generationNb = 1
populationId = 1
frameNb = 0
fitnessStart = 0

oldPopulations = {}
species = {}
population = {}

function copy(orig)
    local copy = {}
    for orig_key, orig_value in next, orig, nil do
        copy[copier(orig_key)] = copier(orig_value)
    end
    setmetatable(copy, copier(getmetatable(orig)))
    return copy
end

function newNeuron(network, id, type, bias)
    local neuron = {}
    
    neuron.bias = bias
    neuron.id = id
    neuron.type = type

    table.insert(network.neurons, neuron)
end

function newConnection(network, neuron_in, neuron_out)
    local connection = {}
    
    connection.weight = generateWeight() -- ???
    connection.neuron_in = neuron_in
    connection.neuron_out = neuron_out
    connection.innov = innovationNb
    connection.enabled = true

    table.insert(network.connections, connection)
    innovationNb = innovationNb + 1
end

function newNetwork(neuron_nb, fitness, id_parent_species)
    local network = {}

    network.nb = neuron_nb or 0
    network.fitness = fitness or 1
    network.id = id_parent_species or 0

    network.neurons = {}
    network.connections = {}

    for id = 1, NB_INPUT do
        newNeuron(network, id, NEURONS.INPUT, 1)
    end

    for id = 1 + NB_INPUT, NB_OUTPUT + NB_INPUT do
        newNeuron(network, id, NEURONS.OUTPUT, 0)
    end

    return network
end

function newSpecies(childs, fitness_average, fitness_max)
    local species = {}

    species.childs = childs or 0
    species.average = fitness_average or 0
    species.max = fitness_max or 0

    species.networks = {}

    return species
end

function newPopulation()
    local pop = {}
    
    for _ = 1, NB_INDIVIDUAL_POPULATION do
        table.insert(pop, newNetwork())
    end
    
    return pop
end

function newGeneration(pop, species)
    local new = newPopulation()
    local nb = NB_INDIVIDUAL_POPULATION
    local index = 1

    local fitnessMaxPop = 0
    local fitnessMaxOldPop = 0
    local stronger = {}

    for i = 1, #pop do
        if fitnessMaxPop < pop[i].fitness then
            fitnessMaxPop = pop[i].fitness
        end
    end

    if #oldPopulations > 0 then
        for i = 1, #oldPopulations do
            for j = 1, #oldPopulations[i] do
                if fitnessMaxOldPop < oldPopulations[i][j].fitness then
                    fitnessMaxOldPop = oldPopulations[i][j].fitness
                    stronger = oldPopulations[i][j]
                end
            end
        end
    end

    if fitnessMaxOldPop > fitnessMaxPop then
        for i = 1, #species do
            for j = 1, #species[i].networks do
                species[i].networks[j] = copy(stronger)
            end
        end
    end

    table.insert(oldPopulations, pop)

    local individuals = 0
    local average = 0
    local best = newNetwork()

    for i = 1, #species do
        species[i].average = 0
        species[i].networks.max = 0
        
        for j = 1, #species[i].networks do
            species[i].average = species[i].average + species[i].networks[j].fitness
            average = average + species[i].networks[j].fitness
            individuals = individuals + 1

            if species[i].max < species[i].networks[j].fitness then
                species[i].max = species[i].networks[j].fitness
                if best.fitness < species[i].networks[j].fitness then
                    best = copy(species[i].networks[j])
                end
            end
        end

        species[i].average = species[i].average / #species[i].networks
    end
    
    average = average / individuals
    if best.fitness > END_FITNESS then
        for i = 1, #species do
            for j = 1, #species[i].networks do
                species[i].networks[j] = copy(best)
            end
        end
        average = best.fitness
    end

    table.sort(species,
        function(e1, e2)
            return e1.max > e2.max
        end
    )

	for i = 1, #species do
		local speciesInd = math.ceil(#species[i].networks * species[i].average / average)
		nb = nb - speciesInd
		if nb < 0 then
			speciesInd = speciesInd + nb
			nb = 0
		end
		species[i].childs = speciesInd
 
 
		for j = 1, speciesInd do
			if index > NB_INDIVIDUAL_POPULATION then
				break
			end
 
			local network = crossover(chooseParent(species[i].networks), chooseParent(species[i].networks))
 
			-- on stop la mutation à ce stade
			if average ~= END_FITNESS then
				mutate(network)
			end
 
			network.id = i
			new[index] = copy(network)
			new[index].fitness = 1
			index = index + 1
		end
        
		if index > NB_INDIVIDUAL_POPULATION then
			break
		end
	end
 
	for i = 1, #species do
		species[i] = (species[i].childs == 0) and nil or species[i]
	end
 
	return new
end

function mutateWeights(network)
    for i = 1, #network.connections do
        if network.connections[i].enabled then
            if math.random() < CHANCE_MUTATION_RESET_CONNECTION then
                network.connections[i].weight = generateWeight()
            else
                local sign = (math.random() >= 0.5) and -1 or 1
				network.connections[i].poids = network.connections[i].poids + WEIGHT_CONNECTION_MUTATION_ADD * sign
            end
        end
    end
end

function addConnection(network)
    local list = {}

    for _, v in ipairs(network.neurons) do
        local pos = math.random(#list+1)
        table.insert(list, pos, v)
    end

    local process
    for i = 1, #list do
        for j = 1, #list do
            if i ~= j then
                local neuron1 = list[i]
                local neuron2 = list[j]

                if (neuron1.type == NEURONS.INPUT and neuron2.type == NEURONS.OUTPUT) or
					(neuron1.type == NEURONS.HIDDEN and neuron2.type == NEURONS.HIDDEN) or
					(neuron1.type == NEURONS.HIDDEN and neuron2.type == NEURONS.OUTPUT) then

                    local connected
                    for k = 1, #network.connections do
                        if network.connections[k].neuron_in == neuron1.id and network.connections[k].neuron_out == neuron2 then
                            connected = true
                            break
                        end
                    end

                    if not connected then
                        process = true
                        newConnection(network, neuron1.id, neuron2.id)
                        return
                    end
                end
            end
        end
    end               
end

function addNeuron(network)
    if #network.connections == 0 or network.nb == NB_NEURON_MAX then
        return
    end

    local indexes = {}
    local random = {}

    for i = 1, #network.connections do
        indexes[i] = i
    end

    for _, v in ipairs(indexes) do
        local pos = math.random(#random+1)
        table.insert(random, pos, v)
    end

    for i = 1, #random do
        if network.connections[random[i]].enabled then
            network.connections[random[i]].enabled = false
            network.nb = network.nb + 1
            local index = network.nb + NB_INPUT + NB_OUTPUT
            newNeuron(network, index, NEURONS.HIDDEN, 1)
            newConnection(network, network.connections[random[i]].neuron_in, index)
            newConnection(network, index, network.connections[random[i]].neuron_out)
            break
        end
    end
end

function mutate(network)
    local r = math.random()
    if r < CHANCE_MUTATION_WEIGHT then
        mutateWeights(network)
    end
    if r < CHANCE_MUTATION_CONNECTION then
        addConnection(network)
    end
    if r < CHANCE_MUTATION_NEURON then
        addNeuron(network)
    end
end

function getDisjoint(network1, network2)
    local nb = 0
    
    for i = 1, #network1.connections do
        for j = 1, #network2.connections do
            if network1.connections[i].innov == network1.connections[j].innov then
                nb = nb + 1
            end
        end
    end

    return #network1.connections + #network2.connections - 2 * nb
end

function getDiffWeight(network1, network2)
    local nb = 0
    local total = 0

    for i = 1, #network1.connections do
        for j = 1, #network2.connections do
            if network1.connections[i].innov == network2.connections[j].innov then
                nb = nb + 1
                total = total + math.abs(network1.connections[i].weight - network2.connections[j].weight)
            end
        end
    end

    return (nbConnexion == 0) and 100000 or total / nb
end

function getScore(networkTest, networkRep)
    return (EXCES_COEF * getDisjoint(networkTest, networkRep)) /
    (math.max(#networkTest.connections + #networkRep.connections, 1)) +
    WEIGHTDIFF_COEF * getDiffWeight(networkTest, networkRep)
end

function generateWeight()
	local var = {-1, 1}
	return var[math.random(2)]
end

function sortPopulation(pop)
    local species = {}
    table.insert(species, newSpecies())

    table.insert(species[1].networks, copy(pop[#pop]))

    for i = 1, #pop - 1 do
        local found
        for j = 1, #species do
            local index math.random(#species[j].networks)
            local rep = species[j].networks[index]

            if getScore(pop[i], rep) < DIFF_LIMIT then
                table.insert(species[j].networks, copy(pop[i]))
                found = true
                break
            end
        end

        if not found then
            table.insert(species, newSpecies())
            table.insert(species[#species].networks, copy(pop[i]))
        end
    end

    return species
end

function crossover(network1, network2)
	local good = network1
	local bad = network2
	if good.fitness < bad.fitness then
		good = network1
		bad = network2
	end
    
	local network = copy(good)
 
	for i = 1, #network.connections do
		for j = 1, #bad.connections do
			if network.connections[i].innov == bad.connections[j].innov and bad.connections[j].enabled then
				if math.random() > 0.5 then
					network.connecctions[i] = bad.connections[j]
				end
			end
		end
	end
    
	network.fitness = 1
	return network
end

function chooseParent(spe)
    if #spe == 1 then
        return spe[1]
    end

    local total = 0
	for i = 1, #spe do
		total = total + spe[i].fitness
	end
    
	local limit = math.random(0, total)
	total = 0
	for i = 1, #spe do
		total = total + spe[i].fitness
		if total >= limit then
			return copy(spe[i])
		end
	end
end

population = newPopulation()

mutate(population[1])

for i = 2, #population do
    population[i] = copy(population[1])
    mutate(population[i])
end

species = sortPopulation(population)
population = newGeneration(population, species)

while true do:
    local old = population[populationId].fitness

    updateNetwork(population[populationId])
    feedForward(population[populationId])
    applyOutputs(population[populationId])
















