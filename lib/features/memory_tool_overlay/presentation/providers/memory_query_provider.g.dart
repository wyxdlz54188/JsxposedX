// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'memory_query_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(memoryQueryRepository)
const memoryQueryRepositoryProvider = MemoryQueryRepositoryProvider._();

final class MemoryQueryRepositoryProvider
    extends
        $FunctionalProvider<
          MemoryQueryRepository,
          MemoryQueryRepository,
          MemoryQueryRepository
        >
    with $Provider<MemoryQueryRepository> {
  const MemoryQueryRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'memoryQueryRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$memoryQueryRepositoryHash();

  @$internal
  @override
  $ProviderElement<MemoryQueryRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  MemoryQueryRepository create(Ref ref) {
    return memoryQueryRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MemoryQueryRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MemoryQueryRepository>(value),
    );
  }
}

String _$memoryQueryRepositoryHash() =>
    r'88ddefa708f22d96e30c431ad34a0dfeda794284';

@ProviderFor(getPid)
const getPidProvider = GetPidFamily._();

final class GetPidProvider
    extends $FunctionalProvider<AsyncValue<int>, int, FutureOr<int>>
    with $FutureModifier<int>, $FutureProvider<int> {
  const GetPidProvider._({
    required GetPidFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'getPidProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$getPidHash();

  @override
  String toString() {
    return r'getPidProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<int> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<int> create(Ref ref) {
    final argument = this.argument as String;
    return getPid(ref, packageName: argument);
  }

  @override
  bool operator ==(Object other) {
    return other is GetPidProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$getPidHash() => r'811869c5dbdf7467cecc16849ca657f1a68c880e';

final class GetPidFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<int>, String> {
  const GetPidFamily._()
    : super(
        retry: null,
        name: r'getPidProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  GetPidProvider call({required String packageName}) =>
      GetPidProvider._(argument: packageName, from: this);

  @override
  String toString() => r'getPidProvider';
}
