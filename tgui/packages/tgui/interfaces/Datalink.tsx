// THIS IS A NOVA SECTOR UI FILE
import {
  Button,
  LabeledList,
  NoticeBox,
  Section,
  Stack,
  Table,
} from 'tgui-core/components';
import type { BooleanLike } from 'tgui-core/react';

import { useBackend } from '../backend';
import { Window } from '../layouts';

type Contact = {
  id: string;
  name: string;
  hops: number;
  dist: number;
  power: string;
};

type Command = {
  origin: string;
  text: string;
  expires: number;
  priority: number;
};

type Data = {
  active: BooleanLike;
  state: string;
  net_id: string;
  callsign: string;
  power_class: string;
  range: number;
  relay_depth: number;
  neighbors: number;
  foreign: number;
  lpi: BooleanLike;
  selected: string;
  contacts: Contact[];
  commands: Command[];
};

export const Datalink = () => {
  const { act, data } = useBackend<Data>();
  const {
    active,
    state,
    net_id,
    callsign,
    power_class,
    range,
    relay_depth,
    neighbors,
    foreign,
    lpi,
    selected,
    contacts = [],
    commands = [],
  } = data;

  const hasSelection = !!selected;

  return (
    <Window width={460} height={560}>
      <Window.Content scrollable>
        {!!foreign && (
          <NoticeBox danger>
            Foreign datalink emissions detected in range (signal strength ~
            {foreign}%).
          </NoticeBox>
        )}
        <Section
          title="Transceiver Status"
          buttons={
            <>
              <Button
                icon={active ? 'power-off' : 'power-off'}
                content={active ? 'Online' : 'Offline'}
                color={active ? 'good' : 'bad'}
                onClick={() => act('toggle')}
              />
              <Button
                ml={1}
                icon="low-vision"
                content="LPI"
                selected={!!lpi}
                tooltip="Low-probability-of-intercept: direct line-of-sight contacts only, no relaying, and foreign nets can only spot you with line of sight."
                onClick={() => act('lpi')}
              />
            </>
          }
        >
          <LabeledList>
            <LabeledList.Item label="Callsign">{callsign}</LabeledList.Item>
            <LabeledList.Item label="Net ID">
              <b>{net_id}</b>
            </LabeledList.Item>
            <LabeledList.Item label="State">{state}</LabeledList.Item>
            <LabeledList.Item label="LPI">{lpi ? 'enabled' : 'disabled'}</LabeledList.Item>
            <LabeledList.Item label="Class / Range">
              {power_class} — {range} tiles, relay depth {relay_depth}
            </LabeledList.Item>
            <LabeledList.Item label="Known contacts">
              {neighbors}
            </LabeledList.Item>
          </LabeledList>
        </Section>

        <Section title="Contacts">
          {!contacts.length && <i>No contacts on the net.</i>}
          {!!contacts.length && (
            <Table>
              <Table.Row header>
                <Table.Cell>Name</Table.Cell>
                <Table.Cell>Hops</Table.Cell>
                <Table.Cell>Dist</Table.Cell>
                <Table.Cell />
              </Table.Row>
              {contacts.map((contact) => (
                <Table.Row key={contact.id}>
                  <Table.Cell>{contact.name}</Table.Cell>
                  <Table.Cell color={contact.hops > 1 ? 'cyan' : 'green'}>
                    {contact.hops > 1 ? `${contact.hops} (relayed)` : 'direct'}
                  </Table.Cell>
                  <Table.Cell>{contact.dist} m</Table.Cell>
                  <Table.Cell>
                    <Button
                      content={selected === contact.id ? 'Selected' : 'Select'}
                      selected={selected === contact.id}
                      onClick={() => act('select', { ref: contact.id })}
                    />
                  </Table.Cell>
                </Table.Row>
              ))}
            </Table>
          )}
        </Section>

        <Section title="Issue Command">
          <Stack wrap>
            <Stack.Item>
              <Button
                icon="bullhorn"
                content="Ping"
                color="yellow"
                onClick={() => act('ping')}
              />
            </Stack.Item>
            <Stack.Item>
              <Button
                icon="flag"
                content="Regroup"
                color="yellow"
                onClick={() => act('regroup')}
              />
            </Stack.Item>
            <Stack.Item>
              <Button
                icon="hand"
                content="Hold"
                onClick={() => act('hold')}
              />
            </Stack.Item>
            <Stack.Item>
              <Button
                icon="crosshairs"
                content="Move To"
                disabled={!hasSelection}
                tooltip={
                  hasSelection
                    ? undefined
                    : 'Select a contact to target it first.'
                }
                onClick={() => act('move_to')}
              />
            </Stack.Item>
            <Stack.Item>
              <Button
                icon="eye"
                content="Focus"
                disabled={!hasSelection}
                tooltip={
                  hasSelection
                    ? undefined
                    : 'Select a contact to target it first.'
                }
                onClick={() => act('focus')}
              />
            </Stack.Item>
            <Stack.Item>
              <Button
                icon="comment"
                content="Custom…"
                color="blue"
                onClick={() => act('custom')}
              />
            </Stack.Item>
          </Stack>
        </Section>

        <Section title="Active Commands">
          {!commands.length && <i>No active commands.</i>}
          {!!commands.length && (
            <Table>
              {commands.map((command, index) => (
                <Table.Row key={index}>
                  <Table.Cell color={command.priority ? 'yellow' : undefined}>
                    <b>{command.origin}</b>: {command.text}
                  </Table.Cell>
                  <Table.Cell>{command.expires}s</Table.Cell>
                </Table.Row>
              ))}
            </Table>
          )}
        </Section>
      </Window.Content>
    </Window>
  );
};
