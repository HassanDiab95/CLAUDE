import { Pressable, StyleSheet, Text, TextInput, View } from 'react-native';

export const colors = { brand: '#0f766e', bg: '#f6f7f9', text: '#14181f', muted: '#5d6675', line: '#e3e6ea', warn: '#fff7e6', err: '#b42318' };

export function Field({ label, ...props }) {
  return (
    <View style={s.field}>
      <Text style={s.label}>{label}</Text>
      <TextInput style={s.input} placeholderTextColor={colors.muted} autoCapitalize="none" {...props} />
    </View>
  );
}

export function Button({ title, onPress, ghost, disabled }) {
  return (
    <Pressable onPress={onPress} disabled={disabled}
      style={({ pressed }) => [s.btn, ghost && s.ghost, (pressed || disabled) && { opacity: 0.6 }]}>
      <Text style={[s.btnText, ghost && { color: colors.text }]}>{title}</Text>
    </Pressable>
  );
}

// Simple chip picker used instead of a native dropdown.
export function Chips({ options, value, onChange }) {
  return (
    <View style={s.chips}>
      {options.map(([key, label]) => (
        <Pressable key={key} onPress={() => onChange(key)} style={[s.chip, value === key && s.chipOn]}>
          <Text style={value === key ? { color: '#fff' } : null}>{label}</Text>
        </Pressable>
      ))}
    </View>
  );
}

export function Card({ children }) {
  return <View style={s.card}>{children}</View>;
}

export const s = StyleSheet.create({
  field: { marginBottom: 10 },
  label: { fontSize: 13, color: colors.muted, marginBottom: 4 },
  input: { borderWidth: 1, borderColor: colors.line, borderRadius: 10, padding: 10, backgroundColor: '#fff', color: colors.text },
  btn: { backgroundColor: colors.brand, borderRadius: 10, padding: 12, alignItems: 'center', marginVertical: 4 },
  ghost: { backgroundColor: 'transparent', borderWidth: 1, borderColor: colors.line },
  btnText: { color: '#fff', fontWeight: '600' },
  chips: { flexDirection: 'row', flexWrap: 'wrap', gap: 6, marginBottom: 10 },
  chip: { borderWidth: 1, borderColor: colors.line, borderRadius: 99, paddingHorizontal: 10, paddingVertical: 5, backgroundColor: '#fff' },
  chipOn: { backgroundColor: colors.brand, borderColor: colors.brand },
  card: { backgroundColor: '#fff', borderRadius: 14, borderWidth: 1, borderColor: colors.line, padding: 14, marginBottom: 10, gap: 4 },
  h1: { fontSize: 24, fontWeight: '700', marginBottom: 6, color: colors.text },
  muted: { color: colors.muted },
  notice: { backgroundColor: colors.warn, padding: 10, borderRadius: 10, marginBottom: 10 },
});
