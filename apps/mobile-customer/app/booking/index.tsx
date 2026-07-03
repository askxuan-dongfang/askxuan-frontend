// 预约下单：服务摘要 + 服务项单选 + 日期/时段 + 功德金 + 备注 + 提交
import React, { useState, useMemo } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  TouchableOpacity,
  TextInput,
  Alert,
  ActivityIndicator,
} from 'react-native';
import { useLocalSearchParams, useRouter } from 'expo-router';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useQuery, useMutation } from '@tanstack/react-query';
import { LinearGradient } from 'expo-linear-gradient';
import { getMaster } from '../../src/api/master';
import { getTemple } from '../../src/api/temple';
import { createBooking } from '../../src/api/booking';
import { DFTopNavBar } from '../../src/components/DFTopNavBar';
import { DFPrimaryButton } from '../../src/components/DFPrimaryButton';
import { colors, radius, spacing, fontFamilies } from '../../src/theme/tokens';
import type { CreateBookingInput } from '../../src/types';

// 服务项
const SERVICE_OPTIONS = [
  { id: 'S001', name: '祈福', price: 100 },
  { id: 'S002', name: '供灯', price: 50 },
  { id: 'S003', name: '上香', price: 38 },
  { id: 'S004', name: '开光', price: 200 },
  { id: 'S005', name: '超度', price: 500 },
  { id: 'S007', name: '化太岁', price: 168 },
];

// 时段
const TIME_SLOTS = ['上午', '下午', '晚上'];

// 功德金档位
const MERIT_TIERS = [
  { tier: '随喜', amount: 0 },
  { tier: '小额', amount: 50 },
  { tier: '中额', amount: 100 },
  { tier: '大额', amount: 200 },
];

// 生成未来 7 天日期
function getNext7Days() {
  const days: { date: string; label: string; weekday: string }[] = [];
  const weekNames = ['日', '一', '二', '三', '四', '五', '六'];
  const now = new Date();
  for (let i = 0; i < 7; i++) {
    const d = new Date(now);
    d.setDate(now.getDate() + i);
    const date = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(
      d.getDate()
    ).padStart(2, '0')}`;
    const label = i === 0 ? '今天' : i === 1 ? '明天' : `${d.getMonth() + 1}/${d.getDate()}`;
    days.push({ date, label, weekday: `周${weekNames[d.getDay()]}` });
  }
  return days;
}

export default function BookingScreen() {
  const params = useLocalSearchParams<{
    masterId?: string;
    templeId?: string;
  }>();
  const insets = useSafeAreaInsets();
  const router = useRouter();

  const masterId = params.masterId || 'M001';
  const templeId = params.templeId || 'T001';

  const { data: master, isLoading: masterLoading } = useQuery({
    queryKey: ['master', masterId],
    queryFn: () => getMaster(masterId),
    enabled: !!masterId,
  });
  const { data: temple } = useQuery({
    queryKey: ['temple', templeId],
    queryFn: () => getTemple(templeId),
    enabled: !!templeId,
  });

  const days = useMemo(getNext7Days, []);
  const [selectedService, setSelectedService] = useState(SERVICE_OPTIONS[0]);
  const [selectedDate, setSelectedDate] = useState(days[0]);
  const [selectedSlot, setSelectedSlot] = useState(TIME_SLOTS[0]);
  const [selectedMerit, setSelectedMerit] = useState(MERIT_TIERS[0]);
  const [note, setNote] = useState('');

  // 价格汇总：服务价 + 功德金
  const totalPrice = selectedService.price + selectedMerit.amount;

  // 提交预约
  const mutation = useMutation({
    mutationFn: (input: CreateBookingInput) => createBooking(input),
    onSuccess: (booking) => {
      router.replace({ pathname: '/booking/success', params: { id: booking.id } });
    },
    onError: (err: unknown) => {
      Alert.alert('预约失败', err instanceof Error ? err.message : '请稍后重试');
    },
  });

  const handleConfirm = () => {
    const input: CreateBookingInput = {
      templeId,
      templeName: temple?.name || '',
      masterId,
      masterName: master?.dharmaName || '',
      serviceId: selectedService.id,
      serviceName: selectedService.name,
      bookingDate: selectedDate.date,
      timeSlot: selectedSlot,
      meritMoney: selectedMerit.amount,
      meritMoneyTier: selectedMerit.tier,
      note,
    };
    mutation.mutate(input);
  };

  if (masterLoading) {
    return (
      <View style={styles.container}>
        <DFTopNavBar title="预约服务" />
        <View style={[styles.center, { marginTop: 200 }]}>
          <ActivityIndicator size="large" color={colors.accent.default} />
        </View>
      </View>
    );
  }

  return (
    <View style={styles.container}>
      <DFTopNavBar title="预约服务" />
      <View style={{ height: insets.top + 44 }} />

      <ScrollView
        showsVerticalScrollIndicator={false}
        contentContainerStyle={{ paddingBottom: 100 }}
      >
        {/* 服务摘要卡 */}
        <View style={styles.section}>
          <View style={styles.summaryCard}>
            <LinearGradient
              colors={['#C8A96E', '#A88A50']}
              start={{ x: 0, y: 0 }}
              end={{ x: 1, y: 1 }}
              style={styles.summaryAvatar}
            >
              <Text style={styles.summaryAvatarText}>
                {master?.dharmaName.slice(0, 1)}
              </Text>
            </LinearGradient>
            <View style={styles.summaryInfo}>
              <Text style={styles.summaryName}>{master?.dharmaName}</Text>
              <Text style={styles.summaryMeta}>
                {master?.templeName} · {master?.position}
              </Text>
              <Text style={styles.summaryService}>服务：{selectedService.name}</Text>
            </View>
          </View>
        </View>

        {/* 服务项单选卡片 */}
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>选择服务</Text>
          <View style={styles.serviceGrid}>
            {SERVICE_OPTIONS.map((svc) => {
              const active = selectedService.id === svc.id;
              return (
                <TouchableOpacity
                  key={svc.id}
                  onPress={() => setSelectedService(svc)}
                  style={[styles.serviceOption, active && styles.serviceOptionActive]}
                >
                  <Text
                    style={[
                      styles.serviceOptionName,
                      active && styles.serviceOptionNameActive,
                    ]}
                  >
                    {svc.name}
                  </Text>
                  <Text
                    style={[
                      styles.serviceOptionPrice,
                      active && styles.serviceOptionPriceActive,
                    ]}
                  >
                    ¥{svc.price}
                  </Text>
                </TouchableOpacity>
              );
            })}
          </View>
        </View>

        {/* 日期选择（未来7天横向滚动） */}
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>选择日期</Text>
          <ScrollView horizontal showsHorizontalScrollIndicator={false}>
            {days.map((d) => {
              const active = selectedDate.date === d.date;
              return (
                <TouchableOpacity
                  key={d.date}
                  onPress={() => setSelectedDate(d)}
                  style={[styles.dateItem, active && styles.dateItemActive]}
                >
                  <Text style={[styles.dateLabel, active && styles.dateLabelActive]}>
                    {d.label}
                  </Text>
                  <Text style={[styles.dateWeekday, active && styles.dateLabelActive]}>
                    {d.weekday}
                  </Text>
                </TouchableOpacity>
              );
            })}
          </ScrollView>
        </View>

        {/* 时段选择 */}
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>选择时段</Text>
          <View style={styles.slotRow}>
            {TIME_SLOTS.map((slot) => {
              const active = selectedSlot === slot;
              return (
                <TouchableOpacity
                  key={slot}
                  onPress={() => setSelectedSlot(slot)}
                  style={[styles.slotItem, active && styles.slotItemActive]}
                >
                  <Text style={[styles.slotText, active && styles.slotTextActive]}>
                    {slot}
                  </Text>
                </TouchableOpacity>
              );
            })}
          </View>
        </View>

        {/* 功德金选择 */}
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>功德金</Text>
          <View style={styles.meritRow}>
            {MERIT_TIERS.map((m) => {
              const active = selectedMerit.tier === m.tier;
              return (
                <TouchableOpacity
                  key={m.tier}
                  onPress={() => setSelectedMerit(m)}
                  style={[styles.meritItem, active && styles.meritItemActive]}
                >
                  <Text style={[styles.meritTier, active && styles.meritTierActive]}>
                    {m.tier}
                  </Text>
                  <Text style={[styles.meritAmount, active && styles.meritTierActive]}>
                    {m.amount === 0 ? '随喜' : `¥${m.amount}`}
                  </Text>
                </TouchableOpacity>
              );
            })}
          </View>
        </View>

        {/* 备注文本输入 */}
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>备注</Text>
          <TextInput
            style={styles.noteInput}
            placeholder="请输入您的祈愿或备注（选填）"
            placeholderTextColor={colors.text.tertiary}
            value={note}
            onChangeText={setNote}
            multiline
            maxLength={200}
          />
        </View>

        {/* 价格汇总 */}
        <View style={styles.section}>
          <View style={styles.priceRow}>
            <Text style={styles.priceLabel}>服务费</Text>
            <Text style={styles.priceValue}>¥{selectedService.price}</Text>
          </View>
          <View style={styles.priceRow}>
            <Text style={styles.priceLabel}>功德金</Text>
            <Text style={styles.priceValue}>
              {selectedMerit.amount === 0 ? '随喜' : `¥${selectedMerit.amount}`}
            </Text>
          </View>
          <View style={[styles.priceRow, styles.priceTotalRow]}>
            <Text style={styles.priceTotalLabel}>合计</Text>
            <Text style={styles.priceTotal}>¥{totalPrice}</Text>
          </View>
        </View>
      </ScrollView>

      {/* 底部确认预约按钮 */}
      <View style={[styles.bottomBar, { paddingBottom: insets.bottom + 8 }]}>
        <DFPrimaryButton
          title={mutation.isPending ? '提交中...' : `确认预约并支付 ¥${totalPrice}`}
          onPress={handleConfirm}
          loading={mutation.isPending}
          style={{ flex: 1 }}
        />
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: colors.bg.primary,
  },
  center: {
    alignItems: 'center',
    justifyContent: 'center',
  },
  section: {
    paddingHorizontal: spacing.lg,
    marginTop: spacing.lg,
  },
  sectionTitle: {
    fontSize: 15,
    fontWeight: '600',
    color: colors.text.primary,
    marginBottom: spacing.md,
  },
  // 摘要卡
  summaryCard: {
    flexDirection: 'row',
    backgroundColor: colors.bg.secondary,
    borderRadius: radius.lg,
    borderWidth: 1,
    borderColor: colors.border.default,
    padding: spacing.md,
    alignItems: 'center',
    gap: spacing.md,
  },
  summaryAvatar: {
    width: 56,
    height: 56,
    borderRadius: 28,
    alignItems: 'center',
    justifyContent: 'center',
  },
  summaryAvatarText: {
    fontSize: 22,
    fontWeight: '600',
    color: colors.bg.primary,
    fontFamily: fontFamilies.serif,
  },
  summaryInfo: {
    flex: 1,
  },
  summaryName: {
    fontSize: 16,
    fontWeight: '700',
    color: colors.text.primary,
  },
  summaryMeta: {
    fontSize: 12,
    color: colors.text.tertiary,
    marginTop: 2,
  },
  summaryService: {
    fontSize: 12,
    color: colors.accent.default,
    marginTop: 4,
  },
  // 服务项
  serviceGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: spacing.sm,
  },
  serviceOption: {
    width: '31%',
    paddingVertical: spacing.md,
    alignItems: 'center',
    borderRadius: radius.md,
    borderWidth: 1,
    borderColor: colors.border.default,
    backgroundColor: colors.bg.secondary,
  },
  serviceOptionActive: {
    borderColor: colors.accent.default,
    backgroundColor: 'rgba(200, 169, 110, 0.08)',
  },
  serviceOptionName: {
    fontSize: 13,
    color: colors.text.secondary,
  },
  serviceOptionNameActive: {
    color: colors.accent.default,
    fontWeight: '600',
  },
  serviceOptionPrice: {
    fontSize: 12,
    color: colors.text.tertiary,
    marginTop: 2,
  },
  serviceOptionPriceActive: {
    color: colors.brand.default,
  },
  // 日期
  dateItem: {
    width: 64,
    paddingVertical: spacing.md,
    marginRight: spacing.sm,
    alignItems: 'center',
    borderRadius: radius.md,
    borderWidth: 1,
    borderColor: colors.border.default,
    backgroundColor: colors.bg.secondary,
  },
  dateItemActive: {
    borderColor: colors.accent.default,
    backgroundColor: 'rgba(200, 169, 110, 0.08)',
  },
  dateLabel: {
    fontSize: 14,
    fontWeight: '600',
    color: colors.text.secondary,
  },
  dateWeekday: {
    fontSize: 11,
    color: colors.text.tertiary,
    marginTop: 2,
  },
  dateLabelActive: {
    color: colors.accent.default,
  },
  // 时段
  slotRow: {
    flexDirection: 'row',
    gap: spacing.sm,
  },
  slotItem: {
    flex: 1,
    paddingVertical: spacing.md,
    alignItems: 'center',
    borderRadius: radius.md,
    borderWidth: 1,
    borderColor: colors.border.default,
    backgroundColor: colors.bg.secondary,
  },
  slotItemActive: {
    borderColor: colors.accent.default,
    backgroundColor: 'rgba(200, 169, 110, 0.08)',
  },
  slotText: {
    fontSize: 14,
    color: colors.text.secondary,
  },
  slotTextActive: {
    color: colors.accent.default,
    fontWeight: '600',
  },
  // 功德金
  meritRow: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: spacing.sm,
  },
  meritItem: {
    width: '23%',
    paddingVertical: spacing.md,
    alignItems: 'center',
    borderRadius: radius.md,
    borderWidth: 1,
    borderColor: colors.border.default,
    backgroundColor: colors.bg.secondary,
  },
  meritItemActive: {
    borderColor: colors.accent.default,
    backgroundColor: 'rgba(200, 169, 110, 0.08)',
  },
  meritTier: {
    fontSize: 13,
    color: colors.text.secondary,
  },
  meritAmount: {
    fontSize: 11,
    color: colors.text.tertiary,
    marginTop: 2,
  },
  meritTierActive: {
    color: colors.accent.default,
    fontWeight: '600',
  },
  // 备注
  noteInput: {
    backgroundColor: colors.bg.secondary,
    borderWidth: 1,
    borderColor: colors.border.default,
    borderRadius: radius.md,
    padding: spacing.md,
    color: colors.text.primary,
    fontSize: 14,
    minHeight: 80,
    textAlignVertical: 'top',
  },
  // 价格
  priceRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    paddingVertical: spacing.sm,
  },
  priceLabel: {
    fontSize: 13,
    color: colors.text.tertiary,
  },
  priceValue: {
    fontSize: 13,
    color: colors.text.secondary,
  },
  priceTotalRow: {
    borderTopWidth: 1,
    borderTopColor: colors.border.divider,
    marginTop: spacing.sm,
    paddingTop: spacing.md,
  },
  priceTotalLabel: {
    fontSize: 15,
    fontWeight: '600',
    color: colors.text.primary,
  },
  priceTotal: {
    fontSize: 18,
    fontWeight: '700',
    color: colors.brand.default,
  },
  bottomBar: {
    position: 'absolute',
    bottom: 0,
    left: 0,
    right: 0,
    backgroundColor: colors.bg.secondary,
    borderTopColor: colors.border.divider,
    borderTopWidth: 1,
    padding: spacing.lg,
  },
});
