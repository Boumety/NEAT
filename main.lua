FITNESS_LEVEL_FINI = 1000000 -- quand le level est fini, la fitness devient ça
NB_FRAME_RESET_BASE = 33 -- si pendant x frames la fitness n'augmente pas comparé à celle du début, on relance (le jeu tourne à 30 fps au cas où)
NB_FRAME_RESET_PROGRES = 300 -- si il a eu un progrés (diff de la fitness au lancement) on laisse le jeu tourner un peu + longtemps avant le reset
NB_NEURONE_MAX = 100000 -- pour le reseau de neurone, hors input et output
NB_INPUT = 8
NB_OUTPUT = 8
NB_INDIVIDU_POPULATION = 100 -- nombre d'individus créés quand création d'une nouvelle population
-- constante pour trier les especes des populations
EXCES_COEF = 0.50
POIDSDIFF_COEF = 0.92
DIFF_LIMITE = 1.00
-- mutation 
CHANCE_MUTATION_RESET_CONNEXION = 0.25 -- % de chance que le poids de la connexion soit totalement reset
POIDS_CONNEXION_MUTATION_AJOUT = 0.80 -- poids ajouté à la mutation de la connexion si pas CHANCE_MUTATION_RESET_CONNEXION. La valeur peut être passée negative
CHANCE_MUTATION_POIDS = 0.95
CHANCE_MUTATION_CONNEXION = 0.85
CHANCE_MUTATION_NEURONE = 0.39

local NEURONS = {
    INPUT = "input",
    OUTPUT = "output",
    HIDDEN = "hidden",
}

nbInnovation = 0 -- nombre d'innovation global pour les connexions, important pour le reseau de neurone
fitnessMax = 0 -- fitness max atteinte 
nbGeneration = 1 -- pour suivre on est à la cb de generation
idPopulation = 1 -- quel id de la population est en train de passer dans la boucle
marioBase = {} -- position de mario a la base ça va me servir pour voir si il avance de sa position d'origine / derniere pos enregistrée
niveauFini = false
lesAnciennesPopulation = {} -- stock les anciennes population
nbFrame = 0 -- nb de frame actuellement
nbFrameStop = 0 -- permettra de reset le jeu au besoin
fitnessInit = 0 -- fitness à laquelle le reseau actuel commence est init
niveauFiniSauvegarde = false
lesEspeces = {}
laPopulation = {}

-- copie un truc et renvoie le truc copié
-- j'ai copié ce code d'ici http://lua-users.org/wiki/CopyTable c vrai en +
function copy(orig)
    local copy = orig
    if type(orig) == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[copier(orig_key)] = copier(orig_value)
        end
        setmetatable(copy, copier(getmetatable(orig)))
    end
    return copy
end
 
-- créé une population
function newPopulation() 
	local population = {}
	for i = 1, NB_INDIVIDU_POPULATION, 1 do
		table.insert(population, newReseau())
	end
	return population
end
 
 
-- créé un neurone
function newNeurone()
	local neurone = {}
	neurone.valeur = 0
	neurone.id = 0 -- pas init si à 0, doit être == à l'indice du neurone dans lesNeurones du reseau
	neurone.type = ""
	return neurone
end
 
-- créé une connexion
function newConnexion()
	local connexion = {}
	connexion.entree = 0 
	connexion.sortie = 0
	connexion.actif = true
	connexion.poids = 0
	connexion.innovation = 0
	connexion.allume = false -- pour le dessin, si true ça veut dire que le resultat de la connexion est different de 0
	return connexion
end
 
-- créé un reseau de neurone 
function newReseau()
	local reseau = {
        nbNeurone = 0,  -- taille des neurones  rajouté par l'algo (hors input output du coup)
		fitness = 1, -- beaucoup de division, pour eviter de faire l irreparable
		idEspeceParent = 0,
		lesNeurones = {}, 
		lesConnexions = {}
    }
    
	for i = 1, NB_INPUT do 
		ajouterNeurone(reseau, i, NEURONS.INPUT, 1)
	end
 
	-- ensuite, les outputs
	for i = NB_INPUT + 1, NB_INPUT + NB_OUTPUT do
		ajouterNeurone(reseau, i, NEURONS.OUTPUT, 0)
	end
 
 
	return reseau
end
 
 
-- créé une espece (un regroupement de reseaux, d'individus)
function newEspece() 
	local espece = {
        nbEnfant = 0, -- combien d'enfant cette espece a créé 
		fitnessMoyenne = 0, -- fitness moyenne de l'espece
		fitnessMax = 0, -- fitness max atteinte par l'espece
		lesReseaux = {}
    }-- tableau qui regroupe les reseaux}
 
	return espece
end

-- ajoute une connexion a un reseau de neurone
function ajouterConnexion(unReseau, entree, sortie, poids)
	-- test pour voir si tout va bien et que les neurones de la connexion existent bien
	if unReseau.lesNeurones[entree].id == 0 then
		console.log("connexion avec l'entree " .. entree .. " n'est pas init ?")
	elseif unReseau.lesNeurones[sortie].id == 0 then
		console.log("connexion avec la sortie " .. sortie .. " n'est pas init ?")
	else
		local connexion = newConnexion()
		connexion.actif = true
		connexion.entree = entree
		connexion.sortie = sortie
		connexion.poids = genererPoids()
		connexion.innovation = nbInnovation
		table.insert(unReseau.lesConnexions, connexion)
		nbInnovation = nbInnovation + 1
	end
end

-- ajoute un neurone a un reseau de neurone, fait que pour les neurones qui doivent exister 
function ajouterNeurone(unReseau, id, type, valeur)
	if id ~= 0 then
		local neurone = newNeurone()
		neurone.id = id
		neurone.type = type
		neurone.valeur = valeur
		table.insert(unReseau.lesNeurones, neurone)
	else
		console.log("ajouterNeurone doit pas etre utilise avec un id == 0")
	end
end
 
-- modifie les connexions d'un reseau de neurone
function mutationPoidsConnexions(unReseau)
	for i = 1, #unReseau.lesConnexions do
		if unReseau.lesConnexions[i].actif then
			if math.random() < CHANCE_MUTATION_RESET_CONNEXION then
				unReseau.lesConnexions[i].poids = genererPoids()
			else
                local sign = (math.random() >= 0.5) and -1 or 1
				unReseau.lesConnexions[i].poids = unReseau.lesConnexions[i].poids + POIDS_CONNEXION_MUTATION_AJOUT * sign
			end
		end
	end
end
 
-- ajoute une connexion entre 2 neurones pas déjà connecté entre eux
-- ça peut ne pas marcher si aucun neurone n'est connectable entre eux (uniquement si beaucoup de connexion)
function mutationAjouterConnexion(unReseau)
	local liste = {}
 
	-- randomisation + copies des neuronnes dans une liste
	for _, v in ipairs(unReseau.lesNeurones) do
		local pos = math.random(#liste)
		table.insert(liste, pos, v)
	end
 
	-- la je vais lister tous les neurones et voir si une pair n'a pas de connexion; si une connexion peut être créée 
	-- on la créée et on stop
	local traitement
	for i = 1, #liste do
		for j = 1, #liste do
			if i ~= j then
				local neurone1 = liste[i]
				local neurone2 = liste[j]
 
 
				if (neurone1.type == NEURONS.INPUT and neurone2.type == NEURONS.OUTPUT) or
					(neurone1.type == NEURONS.HIDDEN and neurone2.type == NEURONS.HIDDEN) or
					(neurone1.type == NEURONS.HIDDEN and neurone2.type == NEURONS.OUTPUT) then
					-- si on en est là, c'est que la connexion peut se faire, juste à tester si y pas deja une connexion
					local dejaConnexion
					for k = 1, #unReseau.lesConnexions do
						if unReseau.lesConnexions[k].entree == neurone1.id
							and unReseau.lesConnexions[k].sortie == neurone2.id then
							dejaConnexion = true
							break
						end
					end
 
 
 
					if not dejaConnexion then
						-- nouvelle connexion, traitement terminé 
						traitement = true
						ajouterConnexion(unReseau, neurone1.id, neurone2.id)
					end
				end
			end
			if traitement then 
				break
			end
		end
		if traitement then 
			break
		end
	end
 
 
	if not traitement then
		console.log("impossible de recreer une connexion")
	end
end
 
-- ajoute un neurone (couche caché uniquement) entre 2 neurones déjà connecté. Ne peut pas marcher
-- si il n'y a pas de connexion 
function mutationAjouterNeurone(unReseau)
	if #unReseau.lesConnexions == 0 then
		log("Impossible d'ajouter un neurone entre 2 connexions si pas de connexion")
		return
    elseif unReseau.nbNeurone == NB_NEURONE_MAX then
		console.log("Nombre de neurone max atteint")
		return
	end
 
	-- randomisation de la liste des connexions
	local listeIndice = {}
	local listeRandom = {}
 
	-- je créé une liste d'entier de 1 à la taille des connexions
	for i = 1, #unReseau.lesConnexions do
		listeIndice[i] = i
	end
 
	-- je randomise la liste que je viens de créer dans listeRandom
	for _, v in ipairs(listeIndice) do
		local pos = math.random(#listeRandom)
		table.insert(listeRandom, pos, v)
	end
 
	for i = 1, #listeRandom do
		if unReseau.lesConnexions[listeRandom[i]].actif then
			unReseau.lesConnexions[listeRandom[i]].actif = false
			unReseau.nbNeurone = unReseau.nbNeurone + 1
            
			local indice = unReseau.nbNeurone + NB_INPUT + NB_OUTPUT 
			ajouterNeurone(unReseau, indice, NEURONS.HIDDEN, 1)
			ajouterConnexion(unReseau, unReseau.lesConnexions[listeRandom[i]].entree, indice, genererPoids())
			ajouterConnexion(unReseau, indice, unReseau.lesConnexions[listeRandom[i]].sortie, genererPoids())
            
			break
		end
	end
end
 
-- appelle une des mutations aléatoirement en fonction des constantes
function mutation(unReseau)
	local random = math.random()
	if random < CHANCE_MUTATION_POIDS then
		mutationPoidsConnexions(unReseau)
	end
	if random < CHANCE_MUTATION_CONNEXION then
		mutationAjouterConnexion(unReseau)
	end
	if random < CHANCE_MUTATION_NEURONE then
		mutationAjouterNeurone(unReseau)
	end
end
 
 
-- place la population et la renvoie divisée dans une tableau 2D
function trierPopulation(laPopulation)
	local lesEspeces = {}
	table.insert(lesEspeces, newEspece())
 
	-- la premiere espece créée et le dernier element de la premiere population
	-- comme ça, j'ai déjà une première espèce créée
	table.insert(lesEspeces[1].lesReseaux, copy(laPopulation[#laPopulation]))
 
	for i = 1, #laPopulation - 1 do
		local trouve
		for j = 1, #lesEspeces do
			local indice = math.random(#lesEspeces[j].lesReseaux)
			local rep = lesEspeces[j].lesReseaux[indice]
			-- il peut être classé 
			if getScore(laPopulation[i], rep) < DIFF_LIMITE then
				table.insert(lesEspeces[j].lesReseaux, copier(laPopulation[i]))
				trouve = true
				break
			end
		end
 
		-- si pas trouvé, il faut créer une especes pour l'individu
		if not trouve then
			table.insert(lesEspeces, newEspece())
			table.insert(lesEspeces[#lesEspeces].lesReseaux, copier(laPopulation[i]))
		end
	end
 
	return lesEspeces
end
 
-- retourne la difference de poids de 2 réseaux de neurones (uniquement des memes innovations)
function getDiffPoids(unReseau1, unReseau2)
	local nbConnexion = 0
	local total = 0
	for i = 1, #unReseau1.lesConnexions do
		for j = 1, #unReseau2.lesConnexions do
			if unReseau1.lesConnexions[i].innovation == unReseau2.lesConnexions[j].innovation then
				nbConnexion = nbConnexion + 1
				total = total + math.abs(unReseau1.lesConnexions[i].poids - unReseau2.lesConnexions[j].poids)
			end
		end
	end
 
	-- si aucune connexion en commun c'est qu'ils sont trop differents
	-- puis si on laisse comme ça on va diviser par 0 et on va lancer mario maker
	return (nbConnexion == 0) and 100000 or total / nbConnexion
end
 
-- retourne le nombre de connexion qui n'ont aucun rapport entre les 2 reseaux
function getDisjoint(unReseau1, unReseau2)
	local nbPareil = 0
	for i = 1, #unReseau1.lesConnexions do
		for j = 1, #unReseau2.lesConnexions do
			if unReseau1.lesConnexions[i].innovation == unReseau2.lesConnexions[j].innovation then
				nbPareil = nbPareil + 1
			end
		end
	end
 
	-- oui ça marche
	return #unReseau1.lesConnexions + #unReseau2.lesConnexions - 2 * nbPareil
end
 
-- permet d'obtenir le score d'un reseau de neurone, ce qui va le mettre dans une especes
-- rien à voir avec le fitness 
-- unReseauRep et un reseau appartenant deja a une espece 
-- et reseauTest et le reseau qui va etre testé
function getScore(unReseauTest, unReseauRep)
	return (EXCES_COEF * getDisjoint(unReseauTest, unReseauRep)) / 
		(math.max(#unReseauTest.lesConnexions + #unReseauRep.lesConnexions, 1))
		+ POIDSDIFF_COEF * getDiffPoids(unReseauTest, unReseauRep)
end
 
-- genere un poids aléatoire (pour les connexions) egal à 1 ou -1
function genererPoids()
	local var = {-1, 1}
	return var[math.random(2)]
end

-- fonction d'activation
function sigmoid(x)
	local resultat = x / (1 + math.abs(x)) -- curieux
	return resultat >= 0.5
end
 
-- applique les connexions d'un réseau de neurone en modifiant la valeur des neurones de sortie
function feedForward(unReseau)
	-- avant de continuer, je reset à 0 les neurones de sortie
	for i = 1, #unReseau.lesConnexions do
		if unReseau.lesConnexions[i].actif then
			unReseau.lesNeurones[unReseau.lesConnexions[i].sortie].valeur = 0
			unReseau.lesNeurones[unReseau.lesConnexions[i].sortie].allume = false
		end
	end
 
	for i = 1, #unReseau.lesConnexions, 1 do
		if unReseau.lesConnexions[i].actif then
			local avantTraitement = unReseau.lesNeurones[unReseau.lesConnexions[i].sortie].valeur
            -- Input * weight + bias
			unReseau.lesNeurones[unReseau.lesConnexions[i].sortie].valeur = 
							unReseau.lesNeurones[unReseau.lesConnexions[i].entree].valeur * 
							unReseau.lesConnexions[i].poids + 
							unReseau.lesNeurones[unReseau.lesConnexions[i].sortie].valeur
 
			unReseau.lesConnexions[i].allume = avantTraitement ~= unReseau.lesNeurones[unReseau.lesConnexions[i].sortie].valeur
		end
	end
end

-- retourne un melange des 2 reseaux de neurones
function crossover(unReseau1, unReseau2)
	local leBon = unReseau1
	local leNul = unReseau2
	if leBon.fitness < leNul.fitness then
		leBon = unReseau2
		leNul = unReseau1
	end
 
	-- le nouveau reseau va hériter de la majorité des attributs du meilleur
	local leReseau = copy(leBon)
 
	-- sauf pour les connexions où y a une chance que le nul lui donne ses genes
	for i = 1, #leReseau.lesConnexions do
		for j = 1, #leNul.lesConnexions do
			-- si 2 connexions partagent la meme innovation, la connexion du nul peut venir la remplacer 
			-- *seulement si nul est actif, sans ça ça créé des neurones hiddens inutiles*
			if leReseau.lesConnexions[i].innovation == leNul.lesConnexions[j].innovation and leNul.lesConnexions[j].actif then
				if math.random() > 0.5 then
					leReseau.lesConnexions[i] = leNul.lesConnexions[j]
				end
			end
		end
	end
	leReseau.fitness = 1
	return leReseau
end
 
-- renvoie une copie d'un parent choisis dans une espece
function choisirParent(uneEspece)
	if #uneEspece == 0 then
		console.log("uneEspece vide dans choisir parent ??")
	-- il est possible que l'espece ne contienne qu'un seul reseau, dans ce cas là on va pas plus loin
    elseif #uneEspece == 1 then
		return uneEspece[1]
	end
 
	local fitnessTotal = 0
    
	for i = 1, #uneEspece do
		fitnessTotal = fitnessTotal + uneEspece[i].fitness
	end
    
	local limite = math.random(0, fitnessTotal)
	local total = 0
	for i = 1, #uneEspece do
		total = total + uneEspece[i].fitness
		-- si la somme des fitness cumulés depasse total, on renvoie l'espece qui a fait depasser la limite
		if total >= limite then
			return copy(uneEspece[i])
		end
	end
    
	console.log("impossible de trouver un parent ?")
end
 
-- créé une nouvelle generation, renvoie la population créée
-- il faut que les especes soit triée avant appel
function nouvelleGeneration(laPopulation, lesEspeces)
	local laNouvellePopulation = newPopulation()
	-- nombre d'indivu à creer au total
	local nbIndividuACreer = NB_INDIVIDU_POPULATION
	 -- indice qui va servir à savoir OU en est le tab de la nouvelle espece
	local indiceNouvelleEspece = 1
 
	-- il est possible que l'ancien meilleur ait un meilleur fitness
	-- que celui de la nouvelle population (une mauvaise mutation ça arrive très souvent)
	-- dans ce cas je le supprime par l'ancien meilleur histoire d'être SUR d'avoir des enfants
	-- toujours du plus bon
	local fitnessMaxPop = 0
	local fitnessMaxAncPop = 0
	local ancienPlusFort = {}
	for i = 1, #laPopulation do
		fitnessMaxPop = (fitnessMaxPop < laPopulation[i].fitness) and laPopulation[i].fitness or fitnessMaxPop
	end
    
	-- on test que si il y a deja une ancienne population evidamment
	if #lesAnciennesPopulation > 0 then
		-- je vais checker TOUTES les anciennes population pour la fitness la plus élevée
		-- vu que les reseaux vont REmuter, il est possible qu'ils fassent moins bon !
		for i = 1, #lesAnciennesPopulation, do
			for j = 1, #lesAnciennesPopulation[i] do
				if fitnessMaxAncPop < lesAnciennesPopulation[i][j].fitness then
					fitnessMaxAncPop = lesAnciennesPopulation[i][j].fitness
					ancienPlusFort = lesAnciennesPopulation[i][j]
				end
			end
		end
	end
 
	if fitnessMaxAncPop > fitnessMaxPop then
		-- comme ça je suis sur uqe le meilleur dominera totalement
		for i = 1, #lesEspeces do
			for j = 1, #lesEspeces[i].lesReseaux do
				lesEspeces[i].lesReseaux[j] = copy(ancienPlusFort)
			end
		end
		console.log("mauvaise population je reprends la meilleur et ça redevient la base de la nouvelle pop")
		console.log(ancienPlusFort)
	end
 
	table.insert(lesAnciennesPopulation, laPopulation)
 
	-- calcul fitness pour chaque espece
	local nbIndividuTotal = 0
	local fitnessMoyenneGlobal = 0 -- fitness moyenne de TOUS les individus de toutes les especes
	local leMeilleur = newReseau() -- je dois le remettre avant tout, on va essayer de trouver ou i lest
	for i = 1, #lesEspeces do
		lesEspeces[i].fitnessMoyenne = 0
		lesEspeces[i].lesReseaux.fitnessMax = 0
		for j = 1, #lesEspeces[i].lesReseaux do
			lesEspeces[i].fitnessMoyenne = lesEspeces[i].fitnessMoyenne + lesEspeces[i].lesReseaux[j].fitness
			fitnessMoyenneGlobal = fitnessMoyenneGlobal + lesEspeces[i].lesReseaux[j].fitness
			nbIndividuTotal = nbIndividuTotal + 1
 
			if lesEspeces[i].fitnessMax < lesEspeces[i].lesReseaux[j].fitness then
				lesEspeces[i].fitnessMax = lesEspeces[i].lesReseaux[j].fitness
				if leMeilleur.fitness < lesEspeces[i].lesReseaux[j].fitness then
					leMeilleur = copy(lesEspeces[i].lesReseaux[j])
				end
			end
		end
		lesEspeces[i].fitnessMoyenne = lesEspeces[i].fitnessMoyenne / #lesEspeces[i].lesReseaux
	end
 
	-- si le level a été terminé au moins une fois, tous les individus deviennent le meilleur, on ne recherche plus de mutation là
    
	fitnessMoyenneGlobal = fitnessMoyenneGlobal / nbIndividuTotal
	if leMeilleur.fitness == FITNESS_LEVEL_FINI then
		for i = 1, #lesEspeces do
			for j = 1, #lesEspeces[i].lesReseaux do
				lesEspeces[i].lesReseaux[j] = copy(leMeilleur)
			end
		end
		fitnessMoyenneGlobal = leMeilleur.fitness
	end
 
	--tri des especes pour que les meilleurs place leurs enfants avant tout
	table.sort(lesEspeces, function (e1, e2) return e1.fitnessMax > e2.fitnessMax end )
 
	-- chaque espece va créer un certain nombre d'individu dans la nouvelle population en fonction de si l'espece a un bon fitness ou pas
	for i = 1, #lesEspeces do
		local nbIndividuEspece = math.ceil(#lesEspeces[i].lesReseaux * lesEspeces[i].fitnessMoyenne / fitnessMoyenneGlobal)
		nbIndividuACreer = nbIndividuACreer - nbIndividuEspece
		if nbIndividuACreer < 0 then
			nbIndividuEspece = nbIndividuEspece + nbIndividuACreer
			nbIndividuACreer = 0
		end
		lesEspeces[i].nbEnfant = nbIndividuEspece
 
 
		for j = 1, nbIndividuEspece do
			if indiceNouvelleEspece > NB_INDIVIDU_POPULATION then
				break
			end
 
			local unReseau = crossover(choisirParent(lesEspeces[i].lesReseaux), choisirParent(lesEspeces[i].lesReseaux))
 
			-- on stop la mutation à ce stade
			if fitnessMoyenneGlobal ~= FITNESS_LEVEL_FINI then
				mutation(unReseau)
			end
 
			unReseau.idEspeceParent = i
			laNouvellePopulation[indiceNouvelleEspece] = copier(unReseau)
			laNouvellePopulation[indiceNouvelleEspece].fitness = 1
			indiceNouvelleEspece = indiceNouvelleEspece + 1
		end
        
		if indiceNouvelleEspece > NB_INDIVIDU_POPULATION then
			break
		end
	end
 
	-- si une espece n'a pas fait d'enfant, je la delete
	for i = 1, #lesEspeces do
		lesEspeces[i] = (lesEspeces[i].nbEnfant == 0) and nil or lesEspeces[i]
	end
 
	return laNouvellePopulation
end
 
-- mets à jour un réseau de neurone avec ce qu'il y a a l'écran. A appeler à chaque frame quand on en test un reseau
function majReseau(unReseau)
    -- WORK HERE
	lesInputs = getLesInputs()
	for i = 1, NB_INPUT, 1 do
		unReseau.lesNeurones[i].valeur = lesInputs[i]
	end
end
 
-- renvoie l'indice du tableau lesInputs avec les coordonnées x y, peut être utilisé aussi pour acceder aux inputs du réseau de neurone
function getIndiceLesInputs(x, y)
	return x + ((y-1) * NB_TILE_W)
end
 
 
-- renvoie les inputs, sont créées en fonction d'où est mario
function getLesInputs()
	local lesInputs = {}
	return lesInputs
end

	laPopulation = newPopulation() 
 
	for i = 1, #laPopulation do
		mutation(laPopulation[i])
	end	
 
	for i = 2, #laPopulation do
		laPopulation[i] = copy(laPopulation[1])
		mutation(laPopulation[i])
	end	
 
	lesEspeces = trierPopulation(laPopulation)
	laPopulation = nouvelleGeneration(laPopulation, lesEspeces)
 
	-- boucle principale 
	while true do
 
		-- ça va permettre de suivre si pendant cette frame il y a du l'evolution
		local fitnessAvant = laPopulation[idPopulation].fitness
 
		majReseau(laPopulation[idPopulation])
		feedForward(laPopulation[idPopulation])
		appliquerLesBoutons(laPopulation[idPopulation])
 
 
		if nbFrame == 0 then
			fitnessInit = laPopulation[idPopulation].fitness
		end
 
		nbFrame = nbFrame + 1
 
		if fitnessMax < laPopulation[idPopulation].fitness then
			fitnessMax = laPopulation[idPopulation].fitness
		end
 
		-- si pas d'évolution ET que le jeu n'est pas en pause, on va voir si on reset ou pas
		if fitnessAvant == laPopulation[idPopulation].fitness and memory.readbyte(0x13D4) == 0 then
			nbFrameStop = nbFrameStop + 1
			local nbFrameReset = NB_FRAME_RESET_BASE
			-- si il y a eu progrés ET QUE mario n'est pas MORT
			if fitnessInit ~= laPopulation[idPopulation].fitness and memory.readbyte(0x0071) ~= 9 then
				nbFrameReset = NB_FRAME_RESET_PROGRES
			end
			if nbFrameStop > nbFrameReset then
				nbFrameStop = 0
				lancerNiveau()
				idPopulation = idPopulation + 1
				-- si on en est là, on va refaire une generation
				if idPopulation > #laPopulation then
					-- je check avant tout si le niveau a pas été terminé 
					if not niveauFiniSauvegarde then
						for i = 1, #laPopulation, 1 do
							-- le level a été fini une fois, 
							if laPopulation[i].fitness == FITNESS_LEVEL_FINI then
								sauvegarderPopulation(laPopulation, true)
								niveauFiniSauvegarde = true
								console.log("Niveau fini apres " .. nbGeneration .. " generation !")
							end
						end
					end
					idPopulation = 1
					nbGeneration = nbGeneration + 1
					lesEspeces = trierPopulation(laPopulation)
					laPopulation = nouvelleGeneration(laPopulation, lesEspeces)
					nbFrame = 0
					fitnessInit = 0
				end
			end
		else
			nbFrameStop = 0
		end
	end
end 
