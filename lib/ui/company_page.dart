import 'package:flutter/material.dart';

import '../core/format.dart';
import '../models/models.dart';
import '../state/session.dart';
import 'theme.dart';
import 'widgets.dart';

/// 招聘者：我的企业主页（信息来自后端，暂不支持直接编辑）
class CompanyPage extends StatefulWidget {
  const CompanyPage({super.key});

  @override
  State<CompanyPage> createState() => _CompanyPageState();
}

class _CompanyPageState extends State<CompanyPage> {
  Company? _company;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final session = AppScope.read(context);
    setState(() {
      _company = null;
      _error = null;
    });
    try {
      final company = await session.api.myCompany(session.token!);
      if (!mounted) return;
      setState(() => _company = company);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final company = _company;
    return Scaffold(
      backgroundColor: bgPage,
      appBar: AppBar(title: const Text('我的企业')),
      body: _error != null
          ? ErrorView(error: _error!, onRetry: _load)
          : company == null
              ? const Center(child: CircularProgressIndicator(strokeWidth: 2.5))
              : ListView(
                  padding: const EdgeInsets.only(bottom: 24),
                  children: [
                    Container(
                      margin: const EdgeInsets.all(12),
                      padding: const EdgeInsets.all(20),
                      decoration: surfaceDecoration(),
                      child: Column(children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: brandColor.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(radiusInner),
                          ),
                          child: const Icon(Icons.business_outlined, size: 34, color: brandDeep),
                        ),
                        const SizedBox(height: 12),
                        Text(company.name,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 6),
                        Wrap(spacing: 6, runSpacing: 4, children: [
                          if (company.industry != null && company.industry!.isNotEmpty)
                            TagChip(company.industry!),
                          if (company.location != null && company.location!.isNotEmpty)
                            TagChip(company.location!),
                        ]),
                        const SizedBox(height: 12),
                        Text('创建于 ${relativeTime(company.createdAt)}',
                            style: const TextStyle(fontSize: 11, color: Color(0xFFB8BCC4))),
                      ]),
                    ),
                    SectionCard(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const SectionTitle('企业信息'),
                        KeyValueRow('行业', company.industry ?? '未填写'),
                        KeyValueRow('所在城市', company.location ?? '未填写'),
                        KeyValueRow('详细地址', company.address ?? '未填写'),
                        KeyValueRow('官网', company.website ?? '未填写'),
                      ]),
                    ),
                    if (company.description != null && company.description!.isNotEmpty)
                      SectionCard(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const SectionTitle('企业介绍'),
                          Text(company.description!,
                              style: const TextStyle(fontSize: 14, height: 1.6, color: Color(0xFF3A3F45))),
                        ]),
                      ),
                  ],
                ),
    );
  }
}
