pico-8 cartridge // http://www.pico-8.com
version 14
__lua__

--[[

a turn consists of the following sequence:
- perform actions
- buy cards
- discard whole hand
- draw 4 new cards
- pass turn to next player

--]]

-- constants
max_possible_players = 6
max_hand_size = 4
shop_hand_size = 4
card_w = 24
card_h = 40
card_spacing = 6
card_spacing_vert = 12
current_player_color = 9

starting_health = 10
winning_points = 20

selection = {
  none = {},
  hand = {},
  shop = {},
  players = {},
  main_menu_players = {}
}

effect_types = {
  steal_points = {
    spr_num = 13
  },
  discard_cards = {
    spr_num = 12
  },
  take_first_player = {
    spr_num = 11
  },
  damage_self = {
    spr_num = 19
  },
  add_actions = {
    spr_num = 10
  },
  draw_cards = {
    spr_num = 9
  },
  gold = {
    spr_num = 6
  },
  points = {
    spr_num = 7
  },
  attack_all = {
    spr_num = 18
  },
  attack_one = {
    spr_num = 2
  },
  heal = {
    spr_num = 3
  },
  none = {
    spr_num = 0
  }
}

game_states = {
  main_menu = {},
  normal = {},
  next_turn_screen = {}
}

-- vars
dbg1 = ''
dbg2 = ''
dbg3 = ''
dbg4 = ''
dbg5 = ''

num_players = 2

-- who has the first player counter?
next_first_player = 1
last_first_player = next_first_player

current_turn = 1
cur_player_actions = 0

status_msg = 'select a card to activate'

wait_counter = 0
wait_callback = nil

-- phases:
-- 1: action
-- 2: buy
current_phase = 1

players = {
  [1] = {
    health = starting_health,
    points = 0,
    gold = 0,
    deck = {},
    hand = {},
    discard_pile = {}
  },
  [2] = {
    health = starting_health,
    points = 0,
    gold = 0,
    deck = {},
    hand = {},
    discard_pile = {}
  },
  [3] = {
    health = starting_health,
    points = 0,
    gold = 0,
    deck = {},
    hand = {},
    discard_pile = {}
  },
  [4] = {
    health = starting_health,
    points = 0,
    gold = 0,
    deck = {},
    hand = {},
    discard_pile = {}
  },
  [5] = {
    health = starting_health,
    points = 0,
    gold = 0,
    deck = {},
    hand = {},
    discard_pile = {}
  },
  [6] = {
    health = starting_health,
    points = 0,
    gold = 0,
    deck = {},
    hand = {},
    discard_pile = {}
  },
  shop = {
    deck = {},
    hand = {},
    discard_pile = {}
  }
}

cur_card_activation = nil
cur_active_card_effect_num = nil
cur_active_card = nil

cur_selection_kind = selection.main_menu_players
selected_index = 2

cur_game_state = game_states.main_menu

-- special callbacks

function _update()
  if wait_counter > 0 then
    wait_counter -= 1
    if wait_counter == 0 and wait_callback then
      wait_callback()
      wait_callback = nil
    end
    return
  end

  if cur_game_state == game_states.next_turn_screen then

    if btnp(4) then
      cur_game_state = game_states.normal
    end

    return
  elseif cur_game_state == game_states.main_menu then

    if btnp(0) then
      pressed_left()
      num_players = selected_index
    end

    if btnp(1) then
      pressed_right()
      num_players = selected_index
    end

    if btnp(4) then
      cur_game_state = game_states.next_turn_screen
      start_game()
    end

    return
  end

  if btnp(4) then
    activate_current()
  end

  if btnp(5) then
    cancel_current()
  end

  if btnp(0) then
    pressed_left()
  end

  if btnp(1) then
    pressed_right()
  end
end

function _draw()
  cls(1)

  if cur_game_state == game_states.next_turn_screen then
    paint_next_turn_screen()
  elseif cur_game_state == game_states.normal then
    paint_current_hand()
    paint_shop_hand()
    paint_ui()
    debug(0, 0)
  elseif cur_game_state == game_states.main_menu then
    paint_main_menu_screen()
  end
end

-- input functions ---------------------------------------------
function pressed_left()
  sfx(4)
  selected_index = previdx(selected_index, get_max_num_for_selection())
end

function pressed_right()
  sfx(4)
  selected_index = nextidx(selected_index, get_max_num_for_selection())
end

function get_max_num_for_selection()
  local max_num = 0

  if cur_selection_kind == selection.hand then
    max_num = len(cur_hand())
  elseif cur_selection_kind == selection.main_menu_players then
    max_num = max_possible_players
  elseif cur_selection_kind == selection.shop then
    max_num = len(players.shop.hand)
  elseif cur_selection_kind == selection.players then
    max_num = num_players
  end

  return max_num
end

-- game functions ---------------------------------------------

function start_game()
  for i=1,num_players do
    initialize_player_deck(players[i])
    shuffle_deck(players[i].deck)
    draw_cards_from_deck(players[i])

    -- each player starts with one less health
    -- so when num_players = 3 and i = 1, the first player loses 2 health
    -- and the second player loses 1 health
    players[i].health -= num_players - i
  end

  -- add cards to the shop
  initialize_shop_deck(players.shop)
  shuffle_deck(players.shop.deck)
  draw_cards_from_deck(players.shop)

  start_turn()
end

function activate_current()
  -- if there is a card currently being activated, then
  -- we should continue activating that effect
  if cur_card_activation != nil then
    continue_activating_card()
  elseif cur_selection_kind == selection.hand then
    local card = cur_hand()[selected_index]
    activate_card_from_hand(card)
  elseif cur_selection_kind == selection.shop then
    local card = players.shop.hand[selected_index]
    buy_card(card)
  end
end

function cancel_current()
  if cur_selection_kind == selection.shop and current_phase == 2 then
    status_msg = 'p' .. current_turn .. ' skipped buying.'
    wait(10, advance)
  end
end

function continue_activating_card()
  assert(cur_card_activation != nil, 'cur_card_activation must exist')
  coresume(cur_card_activation, cur_active_card)

  local cr_status = costatus(cur_card_activation)

  if cr_status == 'dead' then
    event_card_finished_activating()
  end
end

function event_card_finished_activating()
  cur_card_activation = nil
  cur_active_card_effect_num = nil
  cur_active_card = nil

  update_status_message(1)

  cur_player_actions -= 1

  if selected_index > len(cur_hand()) then
    selected_index = len(cur_hand())
  end

  if cur_player_actions == 0 then 
    advance()
  end
end

function activate_card_from_hand(card)
  if not cur_card_activation then
    cur_card_activation = cocreate(activate_card)
    cur_active_card = card
    cur_active_card_effect_num = 1

    event_started_activating_card()

    -- spend the card!
    del(cur_hand(), card)
    add(cur_discard_pile(), card)
  end

  continue_activating_card()
end

function event_started_activating_card()
  sfx(3)
end

function activate_card(card)
  local fx = card.effects[cur_active_card_effect_num]

  if not fx then
    return 
  end

  activate_effect(fx)

  cur_active_card_effect_num += 1

  activate_card(card)
end

function activate_effect(fx)
  if fx.kind == effect_types.points then
    players[current_turn].points += fx.value
  elseif fx.kind == effect_types.gold then
    players[current_turn].gold += fx.value
  elseif fx.kind == effect_types.damage_self then
    players[current_turn].health -= fx.value
  elseif fx.kind == effect_types.take_first_player then
    set_next_first_player(current_turn)
  elseif fx.kind == effect_types.attack_all then
    for i=1, num_players do
      if current_turn != i then
        players[i].health -= fx.value
      end
    end
  elseif fx.kind == effect_types.add_actions then
    cur_player_actions += fx.value
  elseif fx.kind == effect_types.discard_cards then
    do_effect_discard_cards(fx)
  elseif fx.kind == effect_types.draw_cards then
    do_effect_draw_cards(fx)
  elseif fx.kind == effect_types.attack_one then
    do_effect_attack_one(fx)
  elseif fx.kind == effect_types.steal_points then
    do_effect_steal_points(fx)
  elseif fx.kind == effect_types.heal then
    do_effect_heal(fx)
  end
end

function do_effect_discard_cards(fx)
  local cards_discarded = 0

  while cards_discarded < fx.value do
    if len(cur_hand()) == 0 then
      return
    end

    selected_index = 1
    cur_selection_kind = selection.hand
    status_msg = 'discard a card.'

    yield()

    -- discard the selected card
    local card_to_discard = cur_hand()[selected_index]
    add(cur_discard_pile(), card_to_discard)
    del(cur_hand(), card_to_discard)
    cards_discarded += 1
  end
end

function do_effect_draw_cards(fx)
  local cards_drawn = 0

  while cards_drawn < fx.value do
    if len(cur_hand()) == max_hand_size then
      -- now we must discard a card before we continue
      selected_index = 1
      cur_selection_kind = selection.hand
      status_msg = 'discard a card to draw again.'
      yield()

      -- discard the selected card
      local card_to_discard = cur_hand()[selected_index]
      add(cur_discard_pile(), card_to_discard)
      del(cur_hand(), card_to_discard)
    end

    -- draw a card (which removes it from the deck)
    local card = draw_single_card_from_deck(cur_player())
    -- now add the card to the hand
    add(cur_hand(), card)

    cards_drawn += 1
  end
end

function do_effect_attack_one(fx)
  selected_index = 1

  if current_turn == 1 and num_players > 1 then
    selected_index = 2
  end

  cur_selection_kind = selection.players
  status_msg = 'select a player. deal ' .. fx.value .. ' dmg.'
  yield()
  players[selected_index].health -= fx.value
  status_msg = 'dealt ' .. fx.value .. ' dmg to p' .. selected_index
end

function do_effect_steal_points(fx)
  selected_index = 1

  if current_turn == 1 and num_players > 1 then
    selected_index = 2
  end

  cur_selection_kind = selection.players
  status_msg = 'select a player. steal ' .. fx.value .. ' pts.'
  yield()
  players[current_turn].points += fx.value
  players[selected_index].points -= fx.value
  status_msg = 'stole ' .. fx.value .. ' pts from p' .. selected_index
end

function do_effect_heal(fx)
  selected_index = current_turn
  cur_selection_kind = selection.players
  status_msg = 'select a player. heal ' .. fx.value .. ' dmg.'
  yield()
  players[selected_index].health += fx.value
  status_msg = 'restored ' .. fx.value .. ' health to p' .. selected_index
end

function can_afford_current_shop_card()
  local cur_shop_card = players.shop.hand[selected_index]

  return cur_player().gold >= cur_shop_card.cost
end

-- todo deduct gold
function buy_card(card)
  if can_afford_current_shop_card() then
    del(players.shop.hand, card)
    add(cur_discard_pile(), card)
    event_bought_card()
    status_msg = 'p' .. current_turn .. ' bought a card.'
    wait(15, advance)
  else
    event_cannot_afford_card()
  end
end

function event_bought_card()
  sfx(1)
end

function event_cannot_afford_card()
  status_msg = 'you cannot afford this card.'
  sfx(0)
  wait(8, function() update_status_message(2) end)
end

-- expects a number where 1 is first player, etc
function set_next_first_player(player)
  last_first_player = next_first_player
  next_first_player = player
end

function cur_player()
  return players[current_turn]
end

function advance()
  current_phase = nextidx(current_phase, 2)
  update_status_message(current_phase)

  if current_phase == 1 then 
    -- current phase is 1 (action), so it's the next player's turn
    finished_turn()
  elseif current_phase == 2 then 
    -- current phase is 2 (buy)
    selected_index = 1
    cur_selection_kind = selection.shop
  end
end

function finished_turn()
    -- so we perform "cleanup" for the last player
    perform_cleanup()
    current_turn = nextidx(current_turn, num_players) 
    cur_game_state = game_states.next_turn_screen

    if current_turn == last_first_player then
      finished_round()
    end

    start_turn()
end

function start_turn()
    -- get ready for the next turn
    selected_index = 1
    cur_selection_kind = selection.hand
    sfx(2)

    cur_player_actions = 1
end

function finished_round()
  current_turn = next_first_player
  last_first_player = next_first_player

  discard_hand(players.shop)
  draw_cards_from_deck(players.shop)
end

function update_status_message(phase)
  if current_phase == 1 then
    status_msg = 'select a card to activate'
  elseif current_phase == 2 then
    status_msg = 'buy a card. \x97 to pass.'
  end
end

function perform_cleanup()
  cur_player().gold = 0
  discard_hand(cur_player())
  draw_cards_from_deck(cur_player())
end

function initialize_shop_deck()
  local player = players.shop
  local gold_fx = make_effect(effect_types.gold, 3)
  local gold_3_fx = make_effect(effect_types.gold, 3)
  local gold_4_fx = make_effect(effect_types.gold, 4)
  local points_fx = make_effect(effect_types.points, 1)
  local points_minus_1_fx = make_effect(effect_types.points, -1)
  local points_3_fx = make_effect(effect_types.points, 3)
  local attack_all_fx = make_effect(effect_types.attack_all, 2)
  local attack_one_1_fx = make_effect(effect_types.attack_one, 1)
  local attack_one_2_fx = make_effect(effect_types.attack_one, 2)
  local attack_one_3_fx = make_effect(effect_types.attack_one, 3)
  local cards_fx = make_effect(effect_types.draw_cards, 2)
  local actions_fx = make_effect(effect_types.add_actions, 1)
  local heal_fx = make_effect(effect_types.heal, 1)
  local heal_2_fx = make_effect(effect_types.heal, 2)
  local heal_3_fx = make_effect(effect_types.heal, 3)
  local dmg_self_fx = make_effect(effect_types.damage_self, 2)
  local dmg_self_3_fx = make_effect(effect_types.damage_self, 3)
  local dmg_self_4_fx = make_effect(effect_types.damage_self, 4)
  local take_first_player_fx = make_effect(effect_types.take_first_player, 1)
  local discard_fx = make_effect(effect_types.discard_cards, 2)
  local steal_points_fx = make_effect(effect_types.steal_points, 2)

  add_cards(make_card(2, gold_fx), 4, player)
  add_cards(make_card(4, gold_4_fx), 3, player)
  add_cards(make_card(3, points_fx, actions_fx), 3, player)
  add_cards(make_card(3, attack_one_2_fx), 3, player)
  add_cards(make_card(3, cards_fx, actions_fx), 2, player)
  add_cards(make_card(2, heal_fx), 2, player)
  add_cards(make_card(3, points_fx, attack_one_1_fx), 2, player)
  add_cards(make_card(2, dmg_self_fx, attack_one_3_fx), 2, player)
  add_cards(make_card(6, heal_2_fx, attack_all_fx), 2, player)
  add_cards(make_card(4, gold_fx, actions_fx, dmg_self_4_fx), 2, player)
  add_cards(make_card(3, take_first_player_fx), num_players, player)
  add_cards(make_card(3, discard_fx, heal_3_fx), 3, player)
  add_cards(make_card(4, dmg_self_3_fx, points_3_fx), 3, player)
  add_cards(make_card(5, steal_points_fx), 3, player)
  add_cards(make_card(3, gold_3_fx, actions_fx, points_minus_1_fx), 3, player)
end

function initialize_player_deck(player)
  local gold_fx = make_effect(effect_types.gold, 1)
  local points_fx = make_effect(effect_types.points, 1)
  local attack_one_fx = make_effect(effect_types.attack_one, 1)
  local actions_fx = make_effect(effect_types.add_actions, 1)

  add_cards(make_card(1, gold_fx, actions_fx), 3, player)
  add_cards(make_card(1, points_fx), 3, player)
  add_cards(make_card(1, attack_one_fx), 1, player)
end

function add_cards(card, amount, player)
  assert(amount >= 0, 'amount must be >= 0')

  if amount == 0 then
    return
  end

  for i = 1,amount do
    add(player.deck, card)
  end
end

function draw_cards_from_deck(player)
  local deck = player.deck
  local hand = player.hand
  local discard_pile = player.discard_pile

  local deck_size = len(deck)

  if deck_size < max_hand_size then
    -- draw what you can
    move_x_cards(deck, hand, deck_size)
    shuffle_discard_back_into_deck(player)
    -- draw the rest
    move_x_cards(deck, hand, max_hand_size - deck_size)
  else
    move_x_cards(deck, hand, max_hand_size)
  end
end

-- removes that card from the deck
function draw_single_card_from_deck(player)
  if len(player.deck) == 0 then
    shuffle_discard_back_into_deck(player)
  end

  local c = player.deck[1]
  local r = del(player.deck, c)

  return c
end

function shuffle_discard_back_into_deck(player)
  move_all_cards(player.discard_pile, player.deck)
  shuffle_deck(player.deck)
end

function shuffle_deck(deck)
  deck = shuffle(deck)
end

function discard_hand(player)
  move_all_cards(player.hand, player.discard_pile)
end

function move_all_cards(from, to)
  local cards_to_del = {}

  for card in all(from) do
    add(to, card)
    add(cards_to_del, card)
  end

  for c_to_del in all(cards_to_del) do
    del(from, c_to_del)
  end
end

function move_x_cards(from, to, amount)
  local cards_to_del = {}

  for i = 1,amount do
    local c = from[i]
    add(to, c)
    add(cards_to_del, c)
  end

  for c_to_del in all(cards_to_del) do
    del(from, c_to_del)
  end
end

function make_effect(kind, value)
  local fx = {
    kind = kind,
    value = value
  }

  return fx
end

-- input is all of the effects
function make_card(c, ...)
  local cost = c

  if not c then
    cost = 1
  end

  local effects = {}

  for fx in all({...}) do
    add(effects, fx)
  end

  local c = {
    cost = cost,
    effects = effects
  }
  return c
end

-- painting functions ---------------------------------------------

function paint_main_menu_screen()
  rectfill(0, 0, 127, 127, 2)
  print('mini-deck', 16, 20, 12)

  print('number of players: ', 16, 34, 15)
  print('< ' .. num_players .. ' >', 90, 34, 9)

  print('press \x8e to start game!', 16, 60, 15)
end

function paint_next_turn_screen()
  rectfill(0, 0, 127, 127, 3)
  print('p' .. current_turn .. ', your turn!', 35, 40, 7)
  print('press \x8e to continue...', 20, 80, 7)
end

-- note: 4 cards in hand max
function paint_current_hand()
  for i = 1,max_hand_size do
    local card = cur_hand()[i]
    if (card) then paint_player_card(card, i) end
  end
end

-- note: 4 cards in hand max
function paint_shop_hand()
  for i = 1,shop_hand_size do
    local card = players.shop.hand[i]
    if (card) then paint_shop_card(card, i) end
  end
end

function paint_player_card(card, i)
  paint_card(card, i, 127 - (card_h + card_spacing_vert), selection.hand, false)
end

function paint_shop_card(card, i)
  paint_card(card, i, 28, selection.shop, true)
end

function paint_card(card, card_idx, y0, selection_kind, show_cost)
  local x0 = card_spacing + (card_idx - 1) * (card_w + card_spacing)

  -- also check for mode == selecting
  if (selection_kind == cur_selection_kind) and
    (selected_index == card_idx) then
    y0 -= 2

    local dark_bevel_color = 3
    local light_bevel_color = 11

    if selection_kind == selection.shop and 
      not can_afford_current_shop_card() then
      dark_bevel_color = 2
      light_bevel_color = 14
    end

    rect(x0 - 1, y0 - 1, x0 + card_w + 1, y0 + card_h + 1, dark_bevel_color)
    line(x0, y0 - 1, x0 + card_w + 1, y0 - 1, light_bevel_color)
    line(x0 + card_w + 1, y0, x0 + card_w + 1, y0 + card_h, light_bevel_color)
  end

  rectfill(x0, y0, x0 + card_w, y0 + card_h, 5)

  paint_card_icon(x0, y0, card)

  if show_cost then
    paint_card_cost(x0, y0, card)
  end
end

function paint_card_icon(x, y0, card)
  local y = y0
  local dist_between = 10

  for fx in all(card.effects) do
    paint_card_effect(x + 5, y + 2, fx)
    y += dist_between
  end
end

function paint_card_effect(x, y, fx)
  sprite_idx = fx.kind.spr_num
  if sprite_idx then
    spr(sprite_idx, x, y)
  end
  print(fx.value, x + 10, y + 1, 7)
end

function paint_card_cost(x, y, card)
  rectfill(x + 1, y + card_h - 1, x + card_w - 1, y + card_h - 7, 7)
  print('$', x + card_w / 2 - 3, y + card_h - 6, 9)
  print(card.cost, x + card_w / 2 + 1, y + card_h - 6, 0)
end

function paint_ui()
  paint_money()
  paint_status_message()
  paint_player_bar()
end

function paint_money()
  print('$' .. cur_player().gold, card_spacing, 18, 7)
end

function paint_status_message()
  print(status_msg, card_spacing, 127 - card_spacing_vert + 4, 7)
end

function paint_player_bar()
  local bar_h = 14
  local y = 1
  local row_offset = 7
  local col_offset = 42
  rectfill(0, 0, 127, bar_h, 2)
  -- show health for each player
  local col_count = 0
  for i=1,num_players do
    local x = 10 + col_count * col_offset
    local player = players[i]

    if i % 2 == 1 then
      paint_player_info(player, i, x, y)
    else
      paint_player_info(player, i, x, y + row_offset)
      col_count += 1
    end
  end
end

function paint_player_info(player, player_index, x, y)
  local player_color = 7
  if (player_index == current_turn) then player_color = current_player_color end

  local is_first_player = last_first_player == player_index

  if is_first_player then
    paint_first_player_marker(x - 8, y)
  end

  local selected = false
  if cur_selection_kind == selection.players and
    selected_index == player_index then
    selected = true
  end

  local selected_color = 11

  if selected then
    color(selected_color)
  else
    color(player_color)
  end

  print('p' .. player_index, x - 4, y)

  if selected then
    color(selected_color)
  else
    color(7)
  end

  print(':', x + 4, y)
  spr(4, x + 8, y)
  print(player.health, x + 12, y)
  spr(8, x + 22, y)
  print(player.points, x + 27, y)
end

function paint_first_player_marker(x, y)
  spr(5, x, y)
end

-- utility functions ---------------------------------------------

-- in tenths of a second
function wait(a, optional_callback) 
  wait_counter = a * 3
  wait_callback = optional_callback
end

function get_phase_name(phase_num)
  if phase_num == 1 then
    return 'action'
  elseif phase_num == 2 then
    return 'buy'
  else
    return 'unknown'
  end
end

function cur_deck()
  return cur_player().deck
end

function cur_hand()
  return cur_player().hand
end

function cur_discard_pile()
  return cur_player().discard_pile
end

function shuffle(tbl)
  size = len(tbl)
  for i = size, 1, -1 do
    local rand = rndint(size - 1) + 1
    tbl[i], tbl[rand] = tbl[rand], tbl[i]
  end
  return tbl
end

-- returns the next index, looping over max
-- 1,3 -> 2
-- 2,3 -> 3
-- 3,3 -> 1
function nextidx(cur_idx, max)
  return cur_idx % max + 1
end

-- returns the prev index, looping over max
-- 1,3 -> 3
-- 2,3 -> 1
-- 3,3 -> 2
function previdx(cur_idx, max)
  local p = cur_idx - 1
  if (p == 0) then p = max end
  if (p > max) then p = max end

  return p
end

-- get length of metatable
function len(t)
  return count(t)
end

-- from 0 to x inclusive
function rndint(x)
  return flr(rnd(x + 1))
end

function debug(x,y)
  color(7)
  local line_dist = 6
  print(dbg1,x,y)
  print(dbg2,x,y+line_dist)
  print(dbg3,x,y+line_dist*2)
  print(dbg4,x,y+line_dist*3)
  print(dbg5,x,y+line_dist*4)
end

__gfx__
00000000000000000c007000008800000800000009000000000000004ccccc004cc0000000000000000000000000000000000000000000000000000000000000
00000000000000000cc0700000880000888000009900000009aa00004ccccc004cc000000003000003b003000000000000000000000000000000000000000000
00700700000000000cc070008888880008000000090000009aa9a0004ccccc0040000000773330003b003bb00000000077888000000000000000000000000000
00077000000000000cc000008888880000000000999000009aa9a0004ccccc0040000000766300003b03bbbb9090900076670000000000000000000000000000
00077000000000000cc000000088000000000000000000009aa9a0004000000000000000766700003b000b009999900076670000000000000000000000000000
0070070000000000dddd000000880000000000000000000009aa000040000000000000007667000003bbb0008989800076670000000000000000000000000000
00000000000000000660000000000000000000000000000000000000400000000000000077770000000000009999900077770000000000000000000000000000
00000000888888880660000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000c08080008006660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000cc0800008866666000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000cc8080008860606000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000cc0000008806060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000cc0000008806660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000dddd0000dddd0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000660000006600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000660000006600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000

__gff__
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
010a0000130500f0501500000000000000000000000000002d0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00030000160501b050330503305000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000a00001605016050160501b0501f050240502205024050270502705027050270500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00060000185501b5501f55024550295502b5502b5402b5302b5202b51000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00020000175501b550000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__music__
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000
00 00000000

