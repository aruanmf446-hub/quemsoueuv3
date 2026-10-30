-- Gerado por tools/duel/sync_decks.py a partir de assets/duel/decks. Não edite à mão.
begin;
insert into qse_v3.duel_decks(id,name,card_ids,sort_order) values('lendas_urbanas','Lendas Urbanas',array['lendas_urbanas/bruxa_do_pantano','lendas_urbanas/cobra_grande','lendas_urbanas/dama_de_branco','lendas_urbanas/homem_do_saco','lendas_urbanas/homem_sorridente','lendas_urbanas/jeff_the_killer','lendas_urbanas/loira_do_banheiro','lendas_urbanas/momo','lendas_urbanas/slender_man']::text[],0) on conflict (id) do update set name = excluded.name, card_ids = excluded.card_ids, sort_order = excluded.sort_order;
delete from qse_v3.duel_decks where not (id = any(array['lendas_urbanas']::text[]));
commit;
